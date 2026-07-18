import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/print_helper.dart';
import '../../core/printing/receipt_data.dart';
import '../../core/printing/receipt_factory.dart';
import '../../core/theme/app_colors.dart';
import '../../models/delivery_note.dart';
import '../../models/payment_mode.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  bool _loading = true;
  String? _error;
  List<DeliveryNote> _notes = [];
  List<PaymentMode> _paymentModes = [];
  final Set<String> _selectedDocNums = {};
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = AppScope.of(context).repository;
      final results = await Future.wait([
        repo.fetchDeliveryNotes(),
        repo.fetchPaymentModes(),
      ]);
      if (!mounted) return;
      setState(() {
        _notes = results[0] as List<DeliveryNote>;
        _paymentModes = results[1] as List<PaymentMode>;
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

  List<DeliveryNote> get _selectedNotes =>
      _notes.where((n) => _selectedDocNums.contains(n.docNum)).toList();

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
    final receipt = await showModalBottomSheet<ReceiptData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PaymentSheet(
          notes: notes,
          paymentModes: _paymentModes,
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

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date);
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
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
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
            onRefresh: _load,
            child: _notes.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No open sales found',
                          style: TextStyle(color: AppColors.textSecondary),
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
                                      'Room: ${note.rooming.isEmpty ? '-' : note.rooming}  ·  ${note.bookingName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${_formatDate(note.docDate)}',
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

class _PaymentSheetState extends State<_PaymentSheet> {
  late PaymentMode? _mode;
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode =
        widget.paymentModes.isNotEmpty ? widget.paymentModes.first : null;
    // Prefill with document total so Submit is enabled immediately.
    _amountController.text = _roundMoney(_totalPrice).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  double get _payAmount =>
      _roundMoney(double.tryParse(_amountController.text.trim()) ?? 0);

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

  Future<void> _submit() async {
    if (_mode == null) {
      _showMessage('Select any payment mode.');
      return;
    }
    if (_payAmount <= 0) {
      _showMessage('Enter a valid payment amount.');
      return;
    }
    if (_balance > 0) {
      _showMessage(
        'Payment is less than total. Balance: ${_balance.toStringAsFixed(2)}',
      );
      return;
    }

    setState(() => _saving = true);
    final receipt = ReceiptFactory.fromDeliveryNotes(
      notes: widget.notes,
      paymentMode: _mode!.paymentMode,
      paidAmount: _payAmount,
    );
    try {
      await AppScope.of(context).repository.savePayment(
            notes: widget.notes,
            paymentMode: _mode!,
            amount: _payAmount,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
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
                    DropdownButtonFormField<PaymentMode>(
                      // ignore: deprecated_member_use
                      value: _mode,
                      decoration:
                          const InputDecoration(labelText: 'Payment Mode'),
                      items: widget.paymentModes
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.paymentMode),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _mode = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      onChanged: (_) => setState(() {}),
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
