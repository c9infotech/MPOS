import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/print_helper.dart';
import '../../core/printing/receipt_factory.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/branch_option.dart';
import '../../core/draft/pos_draft_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Product> _products = [];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  final List<CartLine> _cart = [];
  String _currency = 'USD';
  bool _saving = false;
  bool _didLoad = false;
  String _selectedCategory = 'All';
  PosDraftService? _posDrafts;
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final drafts = AppScope.of(context).posDrafts;
    if (_posDrafts != drafts) {
      _posDrafts?.removeListener(_onDraftServiceChanged);
      _posDrafts = drafts;
      _posDrafts!.addListener(_onDraftServiceChanged);
    }
    if (_didLoad) return;
    _didLoad = true;
    if (widget.isActive) {
      _load();
      _applyPendingRestore();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load(silent: true);
      _applyPendingRestore();
    }
  }

  @override
  void dispose() {
    _posDrafts?.removeListener(_onDraftServiceChanged);
    _searchController.dispose();
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDraftServiceChanged() => _applyPendingRestore();

  void _applyPendingRestore() {
    final pending = _posDrafts?.takePendingRestore();
    if (pending == null || !mounted) return;
    setState(() {
      _clearPriceControllers();
      _cart
        ..clear()
        ..addAll(pending.lines);
      _currency = pending.currency;
      if (pending.customer != null) {
        _selectedCustomer = pending.customer!.copy();
      }
      for (final line in _cart) {
        _syncPriceController(line);
      }
    });
  }

  TextEditingController _priceControllerFor(CartLine line) {
    final key = line.product.itemCode;
    final existing = _priceControllers[key];
    if (existing != null) return existing;
    final controller = TextEditingController(
      text: line.withGst > 0
          ? line.withGst.toStringAsFixed(2)
          : line.cartPrice.toStringAsFixed(2),
    );
    _priceControllers[key] = controller;
    return controller;
  }

  void _syncPriceController(CartLine line) {
    final controller = _priceControllerFor(line);
    final value = line.product.isPriceEditable && line.withGst > 0
        ? line.withGst
        : line.cartPrice;
    final text = value.toStringAsFixed(2);
    if (controller.text != text) {
      controller.text = text;
    }
  }

  void _removePriceController(String itemCode) {
    _priceControllers.remove(itemCode)?.dispose();
  }

  void _clearPriceControllers() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    _priceControllers.clear();
  }

  void _updateEditablePrice(CartLine line, String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || parsed < 0) return;
    setState(() {
      // Same as Vue: typed value is with-tax; cartPrice is net of 18%.
      line.withGst = parsed;
      line.cartPrice =
          double.parse((parsed / 1.18).toStringAsFixed(2));
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = AppScope.of(context).repository;
      final results = await Future.wait([
        repo.fetchProducts(),
        repo.fetchCustomers(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _customers = results[1] as List<Customer>;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final types = <String>{};
    var hasOthers = false;
    for (final p in _products) {
      final label = p.categoryLabel;
      if (label == Product.othersCategory) {
        hasOthers = true;
      } else {
        types.add(label);
      }
    }
    final sorted = types.toList()..sort();
    return [
      'All',
      ...sorted,
      if (hasOthers) Product.othersCategory,
    ];
  }

  List<Product> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final matchesSearch =
          q.isEmpty || p.itemName.toLowerCase().contains(q);
      final matchesCategory = _selectedCategory == 'All' ||
          p.categoryLabel == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  double get _subtotal {
    return _cart.fold<double>(
      0,
      (sum, line) => sum + (line.chargeable ? line.cartPrice * line.qty : 0),
    );
  }

  double get _tax => _subtotal * 0.18;

  double get _total => _subtotal + _tax;

  int get _cartItemCount =>
      _cart.fold<int>(0, (sum, line) => sum + line.qty);

  void _addToCart(Product product) {
    final price = _currency == 'USD' ? product.usdPrice : product.tzsPrice;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This product does not have a valid price and cannot be added.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final existing =
        _cart.where((c) => c.product.itemCode == product.itemCode).toList();
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty++;
      } else {
        final uomPrice =
            _currency == 'USD' ? product.usduomPrice : product.tzsuomPrice;
        _cart.add(
          CartLine(
            product: product,
            qty: 1,
            cartPrice: uomPrice > 0 ? uomPrice : price,
            cartUom: product.salUnitMsr,
            chargeable: product.isPremiumDrink,
            withGst: uomPrice > 0 ? uomPrice : price,
          ),
        );
        _syncPriceController(_cart.last);
      }
    });
  }

  void _switchUom(CartLine line) {
    setState(() {
      if (line.cartUom == line.product.salUnitMsr) {
        line.cartUom = line.product.uomName;
        line.cartPrice =
            _currency == 'USD' ? line.product.usdPrice : line.product.tzsPrice;
      } else {
        line.cartUom = line.product.salUnitMsr;
        line.cartPrice = _currency == 'USD'
            ? line.product.usduomPrice
            : line.product.tzsuomPrice;
      }
      line.withGst = line.cartPrice;
      _syncPriceController(line);
    });
  }

  void _repriceCart() {
    for (final line in _cart) {
      if (line.cartUom == line.product.salUnitMsr) {
        line.cartPrice = _currency == 'USD'
            ? line.product.usduomPrice
            : line.product.tzsuomPrice;
      } else {
        line.cartPrice =
            _currency == 'USD' ? line.product.usdPrice : line.product.tzsPrice;
      }
      line.withGst = line.cartPrice;
      _syncPriceController(line);
    }
  }

  Future<void> _pickCustomer() async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers available')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _customers
                .where(
                  (c) =>
                      c.cardName.toLowerCase().contains(query.toLowerCase()) ||
                      c.customerName
                          .toLowerCase()
                          .contains(query.toLowerCase()) ||
                      c.clientName
                          .toLowerCase()
                          .contains(query.toLowerCase()) ||
                      c.agent.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search customer',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        return ListTile(
                          title: Text(c.cardName.isNotEmpty
                              ? c.cardName
                              : c.customerName),
                          subtitle: Text(
                            '${c.currency}  ·  ${c.room.isEmpty ? 'No room' : c.room}',
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _selectedCustomer = selected.copy();
      // Client name is guest info — never pre-fill from account cardName.
      _selectedCustomer!.clientName = '';
      _selectedCustomer!.customerName = '';
      _currency = selected.currency.isEmpty ? 'USD' : selected.currency;
      _repriceCart();
    });

    // Draft flow: need room number + waiter.
    if (_selectedCustomer!.room.trim().isEmpty ||
        _selectedCustomer!.waiter.trim().isEmpty) {
      await _editCustomerInfo(mode: _CustomerInfoMode.draft);
    }
  }

  bool _guestInfoIncomplete(Customer c) {
    return c.agent.trim().isEmpty ||
        c.clientName.trim().isEmpty ||
        c.wbnNo.trim().isEmpty ||
        c.cashSalesNo.trim().isEmpty ||
        c.room.trim().isEmpty;
  }

  Future<void> _editCustomerInfo({
    _CustomerInfoMode mode = _CustomerInfoMode.checkout,
  }) async {
    final customer = _selectedCustomer;
    if (customer == null) return;

    final result = await showDialog<_CustomerInfoResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CustomerInfoDialog(
        customer: customer,
        mode: mode,
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      if (mode == _CustomerInfoMode.checkout) {
        customer.agent = result.agent;
        customer.clientName = result.clientName;
        customer.wbnNo = result.wbnNo;
        customer.cashSalesNo = result.cashSalesNo;
        customer.tin = result.tin;
        customer.customerName = result.clientName;
        customer.contact = result.wbnNo;
      }
      customer.room = result.room;
      customer.waiter = result.waiter;
    });
  }

  Future<({int table, String subdivision})?> _pickTableSubdivision() async {
    var table = 1;
    var subdivision = 'A';

    return showModalBottomSheet<({int table, String subdivision})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Save draft — select room & subdivision',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Room',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(PosDraftService.tableCount, (i) {
                        final n = i + 1;
                        final selected = table == n;
                        return ChoiceChip(
                          label: Text('$n'),
                          selected: selected,
                          onSelected: (_) =>
                              setModalState(() => table = n),
                          selectedColor: AppColors.emerald,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.textOnPrimary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Subdivision',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: PosDraftService.subdivisions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final letter = PosDraftService.subdivisions[i];
                          final selected = subdivision == letter;
                          return ChoiceChip(
                            label: Text(letter),
                            selected: selected,
                            onSelected: (_) =>
                                setModalState(() => subdivision = letter),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.textOnPrimary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        ctx,
                        (table: table, subdivision: subdivision),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text('Save to Room $table · $subdivision'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveDraft() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty — add items first')),
      );
      return;
    }

    if (_selectedCustomer != null &&
        _selectedCustomer!.room.trim().isEmpty) {
      await _editCustomerInfo(mode: _CustomerInfoMode.draft);
      if (!mounted ||
          _selectedCustomer == null ||
          _selectedCustomer!.room.trim().isEmpty) {
        return;
      }
    }

    final selection = await _pickTableSubdivision();
    if (selection == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await AppScope.of(context).posDrafts.saveDraft(
            tableNumber: selection.table,
            subdivision: selection.subdivision,
            lines: List<CartLine>.from(_cart),
            currency: _currency,
            customer: _selectedCustomer,
          );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _selectedCustomer = null;
        _currency = 'USD';
        _clearPriceControllers();
      });
      AppScope.of(context).posDrafts.clearLinkedDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draft saved for Room ${selection.table} · ${selection.subdivision}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkout() async {
    if (_selectedCustomer == null || _selectedCustomer!.cardCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select any customer!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_guestInfoIncomplete(_selectedCustomer!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete customer info before checkout.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      await _editCustomerInfo(mode: _CustomerInfoMode.checkout);
      if (!mounted || _guestInfoIncomplete(_selectedCustomer!)) return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text('Confirm Save?'),
        content: const Text('Do you want to save this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Yes, save it!'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _saving = true);
    final repository = AppScope.of(context).repository;
    try {
      final docNo = await repository.createDeliveryNote(
        customer: _selectedCustomer!,
        currency: _currency,
        lines: _cart,
      );
      final receipt = ReceiptFactory.fromCart(
        customer: _selectedCustomer!,
        lines: List<CartLine>.from(_cart),
        currency: _currency,
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        docNo: docNo,
      );
      await AppScope.of(context).posDrafts.removeLinkedDraftAfterCheckout();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _selectedCustomer = null;
        _currency = 'USD';
        _searchController.clear();
        _selectedCategory = 'All';
        _clearPriceControllers();
      });
      await showPrintAfterSuccessDialog(
        context,
        message: 'Delivery Note saved.',
        receipt: receipt,
      );
      if (!mounted) return;
      await _load(); // refresh products + customers after checkout
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearCart() {
    AppScope.of(context).posDrafts.clearLinkedDraft();
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _currency = 'USD';
      _searchController.clear();
      _selectedCategory = 'All';
      _clearPriceControllers();
    });
  }

  String _displayPrice(Product product) {
    final price = _currency == 'USD' ? product.usdPrice : product.tzsPrice;
    final symbol = _currency == 'USD' ? '\$' : 'TZS';
    return '$symbol ${price.toStringAsFixed(2)}';
  }

  Color _chipColor(int index) {
    final colors = AppColors.categoryColors;
    return colors[index % colors.length];
  }

  int get _productGridCrossAxisCount =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 4 : 2;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.primary, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search products',
                              hintStyle: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.primaryDark,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = _categories[index];
                                final selected = _selectedCategory == cat;
                                final color = _chipColor(index);
                                return ChoiceChip(
                                  label: Text(cat),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() => _selectedCategory = cat);
                                  },
                                  selectedColor: color,
                                  backgroundColor: color.withValues(alpha: 0.28),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? AppColors.textOnPrimary
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  showCheckmark: false,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _pickCustomer,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    color: AppColors.primaryDark,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedCustomer == null
                                          ? 'Select customer'
                                          : (_selectedCustomer!
                                                  .cardName.isNotEmpty
                                              ? _selectedCustomer!.cardName
                                              : _selectedCustomer!
                                                  .customerName),
                                      style: TextStyle(
                                        color: _selectedCustomer == null
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (_selectedCustomer != null)
                                    IconButton(
                                      onPressed: () => _editCustomerInfo(
                                        mode: _CustomerInfoMode.draft,
                                      ),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20),
                                      color: AppColors.primaryDark,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedCustomer != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedCustomer!.cardName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Client: ${_selectedCustomer!.clientName.isEmpty ? '-' : _selectedCustomer!.clientName}'
                                    '  ·  Agent: ${_selectedCustomer!.agent.isEmpty ? '-' : _selectedCustomer!.agent}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'TIN: ${_selectedCustomer!.tin}  ·  Room: ${_selectedCustomer!.room}  ·  $_currency',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'WBNo: ${_selectedCustomer!.wbnNo.isEmpty ? '-' : _selectedCustomer!.wbnNo}'
                                    '  ·  CashSalesNo: ${_selectedCustomer!.cashSalesNo.isEmpty ? '-' : _selectedCustomer!.cashSalesNo}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Products (${_filtered.length})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _productGridCrossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = _filtered[index];
                          return _ProductCard(
                            product: product,
                            priceLabel: _displayPrice(product),
                            onTap: () => _addToCart(product),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
          ),
          _buildCartPanel(),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    return Material(
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      color: AppColors.mintBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            expansionTileTheme: const ExpansionTileThemeData(
              iconColor: AppColors.textPrimary,
              collapsedIconColor: AppColors.textPrimary,
              textColor: AppColors.textPrimary,
              collapsedTextColor: AppColors.textPrimary,
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            backgroundColor: AppColors.mintBar,
            collapsedBackgroundColor: AppColors.mintBar,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$_cartItemCount',
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'View Cart',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$_currency ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
            children: [
              Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    if (_cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No products added',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          itemCount: _cart.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: AppColors.slate200,
                          ),
                          itemBuilder: (context, index) {
                            final line = _cart[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${line.product.itemCode} - ${line.product.itemName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'UoM: ${line.cartUom} – Price: $_currency ',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (line.product.isPriceEditable)
                                        SizedBox(
                                          width: 72,
                                          height: 30,
                                          child: TextField(
                                            controller:
                                                _priceControllerFor(line),
                                            keyboardType:
                                                const TextInputType
                                                    .numberWithOptions(
                                              decimal: true,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                              filled: true,
                                              fillColor: AppColors.surfaceMuted,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'[0-9.]'),
                                              ),
                                            ],
                                            onChanged: (v) =>
                                                _updateEditablePrice(line, v),
                                          ),
                                        )
                                      else
                                        Text(
                                          line.cartPrice.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () => _switchUom(line),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.emerald,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Switch UoM'),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: line.product.isPremiumDrink
                                              ? true
                                              : line.chargeable,
                                          activeColor: AppColors.emerald,
                                          onChanged:
                                              line.product.isPremiumDrink
                                                  ? null
                                                  : (v) {
                                                      setState(() =>
                                                          line.chargeable =
                                                              v ?? false);
                                                    },
                                        ),
                                      ),
                                      const Text(
                                        'Chargeable',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      _QtyButton(
                                        icon: Icons.remove,
                                        onPressed: () {
                                          setState(() {
                                            if (line.qty > 1) {
                                              line.qty--;
                                            } else {
                                              _removePriceController(
                                                line.product.itemCode,
                                              );
                                              _cart.removeAt(index);
                                            }
                                          });
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '${line.qty}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      _QtyButton(
                                        icon: Icons.add,
                                        onPressed: () =>
                                            setState(() => line.qty++),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() {
                                          _removePriceController(
                                            line.product.itemCode,
                                          );
                                          _cart.removeAt(index);
                                        }),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          _amountRow('Sub Total', _subtotal),
                          _amountRow('Tax (18%)', _tax),
                          const Divider(color: AppColors.slate200),
                          _amountRow('Total Amount', _total, bold: true),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: TextButton(
                                    onPressed: _clearCart,
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.chipGrey,
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: const Text(
                                      'Clear Cart',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: _saving ? null : _saveDraft,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.textOnPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save Draft',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: _saving ? null : _checkout,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.emerald,
                                      foregroundColor: AppColors.textOnPrimary,
                                      disabledBackgroundColor:
                                          AppColors.primaryLight,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Checkout',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            '$_currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: bold ? AppColors.emerald : AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CustomerInfoMode { draft, checkout }

class _CustomerInfoResult {
  const _CustomerInfoResult({
    required this.agent,
    required this.clientName,
    required this.wbnNo,
    required this.cashSalesNo,
    required this.room,
    required this.tin,
    required this.waiter,
  });

  final String agent;
  final String clientName;
  final String wbnNo;
  final String cashSalesNo;
  final String room;
  final String tin;
  final String waiter;
}

class _CustomerInfoDialog extends StatefulWidget {
  const _CustomerInfoDialog({
    required this.customer,
    required this.mode,
  });

  final Customer customer;
  final _CustomerInfoMode mode;

  @override
  State<_CustomerInfoDialog> createState() => _CustomerInfoDialogState();
}

class _CustomerInfoDialogState extends State<_CustomerInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _agentCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _wbnCtrl;
  late final TextEditingController _cashSalesCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _tinCtrl;

  List<BranchOption> _waiters = [];
  BranchOption? _selectedWaiter;
  bool _loadingWaiters = true;
  String? _waiterError;

  bool get _isCheckout => widget.mode == _CustomerInfoMode.checkout;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _agentCtrl = TextEditingController(text: c.agent);
    _clientCtrl = TextEditingController(text: c.clientName);
    // Always start blank — do not reuse previously entered / stored values.
    _wbnCtrl = TextEditingController();
    _cashSalesCtrl = TextEditingController();
    _roomCtrl = TextEditingController(text: c.room);
    _tinCtrl = TextEditingController(text: c.tin);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWaiters());
  }

  Future<void> _loadWaiters() async {
    setState(() {
      _loadingWaiters = true;
      _waiterError = null;
    });
    try {
      final repo = AppScope.of(context).repository;
      final list = await repo.fetchBranchList();
      if (!mounted) return;
      BranchOption? selected;
      final current = widget.customer.waiter.trim();
      if (current.isNotEmpty) {
        for (final w in list) {
          if (w.code == current || w.name == current || w.label == current) {
            selected = w;
            break;
          }
        }
      }
      // Single option from BranchList (e.g. { name: "TEST2" }) — preselect it.
      selected ??= list.length == 1 ? list.first : null;
      setState(() {
        _waiters = list;
        _selectedWaiter = selected;
        _loadingWaiters = false;
        if (list.isEmpty) {
          _waiterError = 'No waiters found for this user.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWaiters = false;
        _waiterError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWaiters = false;
        _waiterError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _agentCtrl.dispose();
    _clientCtrl.dispose();
    _wbnCtrl.dispose();
    _cashSalesCtrl.dispose();
    _roomCtrl.dispose();
    _tinCtrl.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  void _reset() {
    if (_isCheckout) {
      _agentCtrl.clear();
      _clientCtrl.clear();
      _wbnCtrl.clear();
      _cashSalesCtrl.clear();
      _tinCtrl.clear();
    }
    _roomCtrl.clear();
    setState(() => _selectedWaiter = null);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedWaiter == null) {
      setState(() => _waiterError = 'Waiter is required');
      return;
    }
    Navigator.of(context).pop(
      _CustomerInfoResult(
        agent: _agentCtrl.text.trim(),
        clientName: _clientCtrl.text.trim(),
        wbnNo: _wbnCtrl.text.replaceAll(RegExp(r'\s+'), ''),
        cashSalesNo: _cashSalesCtrl.text.trim(),
        room: _roomCtrl.text.trim(),
        tin: _tinCtrl.text.trim(),
        waiter: _selectedWaiter!.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isCheckout ? 'Checkout customer info' : 'Customer Info',
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: widget.customer.cardName,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Room No *'),
                validator: (v) => _required(v, 'Room No'),
              ),
              const SizedBox(height: 12),
              if (_loadingWaiters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<BranchOption>(
                  // ignore: deprecated_member_use
                  value: _selectedWaiter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Waiter *',
                    errorText: _waiterError,
                  ),
                  items: _waiters
                      .map(
                        (w) => DropdownMenuItem(
                          value: w,
                          child: Text(
                            w.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _waiters.isEmpty
                      ? null
                      : (v) => setState(() {
                            _selectedWaiter = v;
                            _waiterError = null;
                          }),
                  validator: (v) =>
                      v == null ? 'Waiter is required' : null,
                ),
              if (_isCheckout) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _agentCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Agent *'),
                  validator: (v) => _required(v, 'Agent'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clientCtrl,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'Client Name *'),
                  validator: (v) => _required(v, 'Client Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _wbnCtrl,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'WBNo *',
                    helperText: 'No spaces allowed',
                  ),
                  validator: (v) {
                    final value = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                    if (value.isEmpty) return 'WBNo is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cashSalesCtrl,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'CashSalesNo *'),
                  validator: (v) => _required(v, 'CashSalesNo'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tinCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'TINNo',
                    helperText: 'Optional',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: const Text('Reset')),
        FilledButton(
          onPressed: _loadingWaiters ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.priceLabel,
    required this.onTap,
  });

  final Product product;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.itemName.isEmpty
                      ? product.itemCode
                      : product.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                priceLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: AppColors.emerald),
        ),
      ),
    );
  }
}
