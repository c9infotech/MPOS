import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/print_helper.dart';
import '../../core/printing/receipt_factory.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../core/draft/pos_draft_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

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
    _load();
    _applyPendingRestore();
  }

  @override
  void dispose() {
    _posDrafts?.removeListener(_onDraftServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDraftServiceChanged() => _applyPendingRestore();

  void _applyPendingRestore() {
    final pending = _posDrafts?.takePendingRestore();
    if (pending == null || !mounted) return;
    setState(() {
      _cart
        ..clear()
        ..addAll(pending.lines);
      _currency = pending.currency;
      if (pending.customer != null) {
        _selectedCustomer = pending.customer!.copy();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final units = <String>{};
    for (final p in _products) {
      final u = p.salUnitMsr.trim();
      if (u.isNotEmpty) units.add(u);
    }
    final sorted = units.toList()..sort();
    return ['All', ...sorted];
  }

  List<Product> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final matchesSearch =
          q.isEmpty || p.itemName.toLowerCase().contains(q);
      final matchesCategory = _selectedCategory == 'All' ||
          p.salUnitMsr.trim() == _selectedCategory;
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
            chargeable: false,
            withGst: uomPrice > 0 ? uomPrice : price,
          ),
        );
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
                      c.customerName.toLowerCase().contains(query.toLowerCase()),
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
      _currency = selected.currency.isEmpty ? 'USD' : selected.currency;
      _repriceCart();
    });

    if (_selectedCustomer!.tin.isEmpty) {
      await _editCustomerInfo();
    }
  }

  Future<void> _editCustomerInfo() async {
    final customer = _selectedCustomer;
    if (customer == null) return;

    final nameCtrl = TextEditingController(text: customer.customerName);
    final tinCtrl = TextEditingController(text: customer.tin);
    final contactCtrl = TextEditingController(text: customer.contact);
    final roomCtrl = TextEditingController(text: customer.room);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Customer Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tinCtrl,
                  decoration: const InputDecoration(labelText: 'TIN Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Booking Reference'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(labelText: 'Room Number'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameCtrl.clear();
                tinCtrl.clear();
                contactCtrl.clear();
                roomCtrl.clear();
              },
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
      },
    );

    if (saved == true) {
      setState(() {
        customer.customerName = nameCtrl.text.trim();
        customer.tin = tinCtrl.text.trim();
        customer.contact = contactCtrl.text.trim();
        customer.room = roomCtrl.text.trim();
      });
    }

    nameCtrl.dispose();
    tinCtrl.dispose();
    contactCtrl.dispose();
    roomCtrl.dispose();
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
                      'Save draft — select table & subdivision',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Table',
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
                      child: Text('Save to Table $table · $subdivision'),
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
      setState(() => _cart.clear());
      AppScope.of(context).posDrafts.clearLinkedDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draft saved for Table ${selection.table} · ${selection.subdivision}',
          ),
          backgroundColor: AppColors.success,
        ),
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
    final receipt = ReceiptFactory.fromCart(
      customer: _selectedCustomer!,
      lines: List<CartLine>.from(_cart),
      currency: _currency,
      subtotal: _subtotal,
      tax: _tax,
      total: _total,
    );
    try {
      await repository.createDeliveryNote(
        customer: _selectedCustomer!,
        currency: _currency,
        lines: _cart,
      );
      await AppScope.of(context).posDrafts.removeLinkedDraftAfterCheckout();
      if (!mounted) return;
      setState(() => _cart.clear());
      await showPrintAfterSuccessDialog(
        context,
        message: 'Delivery Note saved.',
        receipt: receipt,
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

  void _clearCart() {
    AppScope.of(context).posDrafts.clearLinkedDraft();
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _currency = 'USD';
      _searchController.clear();
      _selectedCategory = 'All';
    });
  }

  String _displayPrice(Product product) {
    final price = _currency == 'USD' ? product.usdPrice : product.tzsPrice;
    final symbol = _currency == 'USD' ? '\$' : 'TZS';
    return '$symbol ${price.toStringAsFixed(2)}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(3)
        .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
        .join();
  }

  Color _chipColor(int index) {
    final colors = AppColors.categoryColors;
    return colors[index % colors.length];
  }

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
                                      onPressed: _editCustomerInfo,
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
                                    _selectedCustomer!.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'TIN: ${_selectedCustomer!.tin}  ·  $_currency',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Room: ${_selectedCustomer!.room}  ·  Ref: ${_selectedCustomer!.contact}',
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = _filtered[index];
                          return _ProductCard(
                            product: product,
                            priceLabel: _displayPrice(product),
                            initials: _initials(
                              product.itemName.isEmpty
                                  ? product.itemCode
                                  : product.itemName,
                            ),
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
                                  Text(
                                    'UoM: ${line.cartUom} – $_currency ${line.cartPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
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
                                          value: line.chargeable,
                                          activeColor: AppColors.emerald,
                                          onChanged: (v) {
                                            setState(() =>
                                                line.chargeable = v ?? false);
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
                                        onPressed: () => setState(
                                            () => _cart.removeAt(index)),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.priceLabel,
    required this.initials,
    required this.onTap,
  });

  final Product product;
  final String priceLabel;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: ColoredBox(
                  color: AppColors.corporateGray,
                  child: product.image != null && product.image!.isNotEmpty
                      ? Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _InitialsAvatar(initials: initials),
                        )
                      : _InitialsAvatar(initials: initials),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const Spacer(),
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
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.slate700,
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
