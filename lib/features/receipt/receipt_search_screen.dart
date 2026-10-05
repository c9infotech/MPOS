import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/print_helper.dart';
import '../../core/printing/receipt_factory.dart';
import '../../core/theme/app_colors.dart';
import '../../models/invoice_receipt.dart';

/// Search A/R invoices and deliveries by WBno and reprint with SAP QR.
class ReceiptSearchScreen extends StatefulWidget {
  const ReceiptSearchScreen({super.key});

  static const routeName = '/receipt-search';

  @override
  State<ReceiptSearchScreen> createState() => _ReceiptSearchScreenState();
}

class _ReceiptSearchScreenState extends State<ReceiptSearchScreen> {
  final _wbNoController = TextEditingController();
  final _money = NumberFormat('#,##0.00');

  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<InvoiceReceipt> _invoices = [];
  String? _printingKey;

  @override
  void dispose() {
    _wbNoController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final wb = _wbNoController.text.trim();
    if (wb.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a WBno to search'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    try {
      final invoices =
          await AppScope.of(context).repository.fetchInvoiceReceipts(wbNo: wb);
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _invoices = [];
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoices = [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _printInvoice(InvoiceReceipt invoice) async {
    if (_printingKey != null) return;
    setState(() => _printingKey = '${invoice.docType}-${invoice.docEntry}');
    try {
      final receipt = ReceiptFactory.fromInvoiceReceipt(invoice);
      if (!mounted) return;
      await printReceipt(context, receipt, includeCustomerSign: true);
    } finally {
      if (mounted) setState(() => _printingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.textOnPrimary,
        title: const Text('Receipt'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wbNoController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'WBno',
                      hintText: 'e.g. WB34350',
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
                      suffixIcon: _wbNoController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear',
                              onPressed: () => setState(() {
                                _wbNoController.clear();
                                _invoices = [];
                                _searched = false;
                                _error = null;
                              }),
                              icon: const Icon(Icons.clear, size: 18),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 44),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Enter WBno and tap Search to list invoices and deliveries.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No invoices or deliveries for your bar on this WBno.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _invoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final printing = _printingKey == '${inv.docType}-${inv.docEntry}';
        final currency = inv.docCurrency.trim().isEmpty ? 'USD' : inv.docCurrency;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${inv.displayDocType}  ${inv.displayDocNo.isEmpty ? '-' : inv.displayDocNo}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inv.bookingName.trim().isNotEmpty
                            ? inv.bookingName
                            : (inv.cardName.isEmpty ? '-' : inv.cardName),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WBno: ${inv.displayWbNo.isEmpty ? '-' : inv.displayWbNo}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Date: ${_formatDate(inv.docDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currency ${_money.format(inv.docTotal)}'
                        '${inv.items.isEmpty ? '' : ' · ${inv.items.length} lines'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (inv.qrValue.trim().isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'No QR on this ${inv.displayDocType.toLowerCase()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: printing ? null : () => _printInvoice(inv),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print, size: 18),
                  label: const Text('Print'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }
    return DateFormat('dd MMM yyyy').format(parsed);
  }
}
