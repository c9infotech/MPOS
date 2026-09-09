import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/print_helper.dart';
import '../../core/printing/receipt_data.dart';
import '../../core/printing/receipt_factory.dart';
import '../../core/theme/app_colors.dart';
import '../../models/delivery_note.dart';
import '../../models/payment_mode.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({
    super.key,
    this.isActive = true,
    this.filterOpen,
  });

  final bool isActive;
  final ValueNotifier<bool>? filterOpen;

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  bool _loading = true;
  String? _error;
  List<DeliveryNote> _notes = [];
  final Set<String> _selectedDocNums = {};
  bool _didLoad = false;
  bool _filterOpen = false;
  String _activeWbFilter = '';
  final _wbNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.filterOpen?.addListener(_onFilterOpenChanged);
    _filterOpen = widget.filterOpen?.value ?? false;
  }

  @override
  void didUpdateWidget(covariant SalesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterOpen != widget.filterOpen) {
      oldWidget.filterOpen?.removeListener(_onFilterOpenChanged);
      widget.filterOpen?.addListener(_onFilterOpenChanged);
      _filterOpen = widget.filterOpen?.value ?? _filterOpen;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.filterOpen?.removeListener(_onFilterOpenChanged);
    _wbNoController.dispose();
    super.dispose();
  }

  void _onFilterOpenChanged() {
    final open = widget.filterOpen?.value ?? false;
    if (!mounted) return;
    setState(() => _filterOpen = open);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    if (widget.isActive) {
      _load();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _load({String? wbNo}) async {
    final query = (wbNo ?? _activeWbFilter).trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = AppScope.of(context).repository;
      final notes = await repo.fetchDeliveryNotes(wbNo: query);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _activeWbFilter = query;
        _selectedDocNums.clear();
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

  Future<void> _searchByWbNo() async {
    await _load(wbNo: _wbNoController.text);
  }

  Future<void> _clearWbFilter() async {
    _wbNoController.clear();
    await _load(wbNo: '');
  }

  List<DeliveryNote> get _selectedNotes =>
      _notes.where((n) => _selectedDocNums.contains(n.docNum)).toList();

  String? get _selectionCardCode {
    if (_selectedDocNums.isEmpty) return null;
    return _selectedNotes.first.cardCode;
  }

  List<DeliveryNote> get _selectableNotes {
    if (_notes.isEmpty) return const [];
    final code = _selectionCardCode ?? _notes.first.cardCode;
    return _notes.where((n) => n.cardCode == code).toList(growable: false);
  }

  bool get _allSelectableSelected {
    final selectable = _selectableNotes;
    if (selectable.isEmpty) return false;
    return selectable.every((n) => _selectedDocNums.contains(n.docNum));
  }

  void _toggleSelectAll() {
    if (_notes.isEmpty) return;
    if (_allSelectableSelected) {
      setState(() => _selectedDocNums.clear());
      return;
    }
    final selectable = _selectableNotes;
    final skipped = _notes.length - selectable.length;
    setState(() {
      _selectedDocNums
        ..clear()
        ..addAll(selectable.map((n) => n.docNum));
    });
    if (skipped > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected ${selectable.length} from the same customer. '
            '$skipped other customer item(s) skipped.',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  void _toggleSelection(DeliveryNote note, bool? checked) {
    if (checked == true) {
      if (_selectedDocNums.isNotEmpty) {
        final first = _selectedNotes.first;
        if (first.cardCode != note.cardCode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('You can only select items from the same customer.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
      setState(() => _selectedDocNums.add(note.docNum));
    } else {
      setState(() => _selectedDocNums.remove(note.docNum));
    }
  }

  Future<void> _openPayment(List<DeliveryNote> notes) async {
    if (notes.isEmpty) return;
    final customerCode = notes.first.cardCode.trim();
    if (customerCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payment modes available for this customer.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    var loaderVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );

    List<PaymentMode> modesForCustomer;
    try {
      final repo = AppScope.of(context).repository;
      modesForCustomer = await repo.fetchPaymentModes(
        customerCode: customerCode,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (loaderVisible) {
        Navigator.of(context).pop();
        loaderVisible = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      if (loaderVisible) {
        Navigator.of(context).pop();
        loaderVisible = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    if (loaderVisible) {
      Navigator.of(context).pop();
      loaderVisible = false;
    }

    if (modesForCustomer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No payment modes found for customer $customerCode.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final receipt = await showModalBottomSheet<ReceiptData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PaymentSheet(
          notes: notes,
          paymentModes: modesForCustomer,
        );
      },
    );
    if (!mounted) return;
    if (receipt != null) {
      await showPrintAfterSuccessDialog(
        context,
        message: 'Payment saved.',
        receipt: receipt,
      );
      await _load();
    }
  }

  String _formatDate(DeliveryNote note) => note.docDateLabel;

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
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_filterOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wbNoController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchByWbNo(),
                    decoration: InputDecoration(
                      labelText: 'WBno',
                      hintText: 'Filter by WBno',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      suffixIcon: _wbNoController.text.isNotEmpty ||
                              _activeWbFilter.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear',
                              onPressed: _clearWbFilter,
                              icon: const Icon(Icons.clear, size: 18),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _searchByWbNo,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Search'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _notes.isEmpty ? null : _toggleSelectAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryDark),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(
                    _allSelectableSelected ? 'Unselect all' : 'Select all',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (_activeWbFilter.isNotEmpty && !_filterOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('WBno: $_activeWbFilter'),
                onDeleted: _clearWbFilter,
              ),
            ),
          ),
        if (_selectedDocNums.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.appBar,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bulk payment (${_selectedDocNums.length}) selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => _openPayment(_selectedNotes),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                  ),
                  child: const Text('Proceed'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryDark,
            onRefresh: () => _load(),
            child: _notes.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _activeWbFilter.isEmpty
                              ? 'No open sales found'
                              : 'No sales found for WBno "$_activeWbFilter"',
                          style: const TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    itemCount: _notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final selected =
                          _selectedDocNums.contains(note.docNum);
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected
                                ? AppColors.mintBar
                                : AppColors.slate200,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark
                                  .withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (v) => _toggleSelection(note, v),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.cardName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ref: ${note.trackingNumber}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Room: ${note.rooming.isEmpty ? '-' : note.rooming}  ·  ${note.agent.isEmpty ? '-' : note.agent}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${_formatDate(note)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'WBno: ${note.wbNo.isEmpty ? '-' : note.wbNo}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: () => _openPayment([note]),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.emerald,
                                  foregroundColor: AppColors.textOnPrimary,
                                  minimumSize: const Size(56, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Pay'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.notes,
    required this.paymentModes,
  });

  final List<DeliveryNote> notes;
  final List<PaymentMode> paymentModes;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentLineState {
  _PaymentLineState({this.mode, required String initialAmount})
      : amountController = TextEditingController(text: initialAmount);

  PaymentMode? mode;
  final TextEditingController amountController;

  void dispose() => amountController.dispose();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const _chargeToOptions = ['Agent', 'Client'];

  final List<_PaymentLineState> _lines = [];
  String? _chargeTo = 'Agent';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final defaultMode =
        widget.paymentModes.isNotEmpty ? widget.paymentModes.first : null;
    _lines.add(
      _PaymentLineState(
        mode: defaultMode,
        initialAmount: _roundMoney(_totalPrice).toStringAsFixed(2),
      ),
    );
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double _roundMoney(double value) =>
      double.parse(value.toStringAsFixed(2));

  double get _totalItems =>
      widget.notes.fold(0, (sum, n) => sum + n.items.length).toDouble();

  double get _totalQty => widget.notes.fold(
        0,
        (sum, n) => sum + n.items.fold(0.0, (s, i) => s + i.quantity),
      );

  double get _totalTax =>
      _roundMoney(widget.notes.fold(0.0, (sum, n) => sum + n.taxTotal));

  double get _totalPrice =>
      _roundMoney(widget.notes.fold(0.0, (sum, n) => sum + n.grandTotal));

  double _lineAmount(_PaymentLineState line) =>
      _roundMoney(double.tryParse(line.amountController.text.trim()) ?? 0);

  double get _payAmount => _roundMoney(
        _lines.fold<double>(0, (sum, line) => sum + _lineAmount(line)),
      );

  double get _balance => _roundMoney(_totalPrice - _payAmount);

  String get _currency =>
      widget.notes.isNotEmpty ? widget.notes.first.docCurrency : '';

  void _showMessage(String message, {Color background = AppColors.error}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  void _addPaymentLine() {
    if (widget.paymentModes.isEmpty) return;
    final used = _lines.map((l) => l.mode).whereType<PaymentMode>().toSet();
    final nextMode = widget.paymentModes.firstWhere(
      (m) => !used.contains(m),
      orElse: () => widget.paymentModes.first,
    );
    final remaining = _balance > 0 ? _balance : 0.0;
    setState(() {
      _lines.add(
        _PaymentLineState(
          mode: nextMode,
          initialAmount: remaining > 0 ? remaining.toStringAsFixed(2) : '',
        ),
      );
    });
  }

  void _removePaymentLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    if (_chargeTo == null || _chargeTo!.trim().isEmpty) {
      _showMessage('Select Charge to (Agent or Client).');
      return;
    }
    final payments = <({PaymentMode mode, double amount})>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final amount = _lineAmount(line);
      if (amount <= 0) continue;
      if (line.mode == null) {
        _showMessage('Select payment mode for line ${i + 1}.');
        return;
      }
      payments.add((mode: line.mode!, amount: amount));
    }
    if (payments.isEmpty) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    setState(() => _saving = true);
    final receiptLabel =
        payments.map((p) => '${p.mode.paymentMode} ${p.amount.toStringAsFixed(2)}').join(' + ');
    final receipt = ReceiptFactory.fromDeliveryNotes(
      notes: widget.notes,
      paymentMode: receiptLabel,
      paidAmount: _payAmount,
    );
    try {
      await AppScope.of(context).repository.savePayment(
            notes: widget.notes,
            payments: payments,
            chargeTo: _chargeTo!,
          );
      if (!mounted) return;
      Navigator.pop(context, receipt);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final note in widget.notes) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.cardName,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text('Room: ${note.rooming}'),
                              Text('Doc No: ${note.docNum}'),
                              const Divider(),
                              for (var i = 0; i < note.items.length; i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '${i + 1}. ${note.items[i].itemCode}\n${note.items[i].description}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          note.items[i].quantity
                                              .toStringAsFixed(2),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          note.items[i].price.toStringAsFixed(2),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text('Total Items: ${_totalItems.toInt()}'),
                        Text('Total Qty: ${_totalQty.toStringAsFixed(2)}'),
                        Text('Total Tax: ${_totalTax.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryBox(
                            'Total ($_currency)',
                            _totalPrice.toStringAsFixed(2),
                          ),
                        ),
                        Expanded(
                          child: _summaryBox(
                            'Payment',
                            _payAmount.toStringAsFixed(2),
                          ),
                        ),
                        Expanded(
                          child: _summaryBox(
                            'Balance',
                            _balance.toStringAsFixed(2),
                            color: _balance <= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payments',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _chargeTo,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Charge to',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.fromLTRB(16, 18, 12, 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _chargeToOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _chargeTo = v),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _lines.length; i++) ...[
                      _buildPaymentLine(i),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: widget.paymentModes.isEmpty
                            ? null
                            : _addPaymentLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Add payment mode'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryLight,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentLine(int index) {
    final line = _lines[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removePaymentLine(index),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentMode>(
            // ignore: deprecated_member_use
            value: line.mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Payment Mode'),
            items: widget.paymentModes
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.paymentMode, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => line.mode = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: line.amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}
