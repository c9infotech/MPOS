import '../../models/customer.dart';
import '../../models/delivery_note.dart';
import '../../models/invoice_receipt.dart';
import '../../models/product.dart';
import 'receipt_data.dart';

abstract final class ReceiptFactory {
  static ReceiptData fromCart({
    required Customer customer,
    required List<CartLine> lines,
    required String currency,
    required double subtotal,
    required double tax,
    required double total,
    String docNo = '',
  }) {
    final wbNo = customer.wbnNo.isNotEmpty ? customer.wbnNo : customer.contact;
    return ReceiptData(
      title: 'Sales Invoice',
      currency: currency,
      docNo: docNo,
      customerName: customer.clientName.isNotEmpty
          ? customer.clientName
          : (customer.customerName.isNotEmpty
              ? customer.customerName
              : customer.cardName),
      clientName: customer.clientName,
      agent: customer.agent,
      wbNo: wbNo,
      waiter: customer.waiter,
      room: customer.room,
      tin: customer.tin,
      bookingReference: wbNo,
      camp: ReceiptData.campFromCardName(customer.cardName),
      subtotal: subtotal,
      tax: tax,
      total: total,
      lines: lines
          .map(
            (l) => ReceiptLine(
              code: l.product.itemCode,
              name: l.product.itemName,
              qty: l.qty.toDouble(),
              price: l.cartPrice,
              uom: l.cartUom,
            ),
          )
          .toList(),
    );
  }

  static ReceiptData fromDeliveryNotes({
    required List<DeliveryNote> notes,
    required String paymentMode,
    required double paidAmount,
  }) {
    final first = notes.first;
    final lines = <ReceiptLine>[];
    for (final note in notes) {
      for (final item in note.items) {
        lines.add(
          ReceiptLine(
            code: item.itemCode,
            name: item.description,
            qty: item.quantity,
            price: item.price,
          ),
        );
      }
    }
    final subtotal = notes.fold<double>(0, (s, n) => s + n.lineTotal);
    final tax = notes.fold<double>(0, (s, n) => s + n.taxTotal);
    final total = notes.fold<double>(0, (s, n) => s + n.grandTotal);
    final orderNumbers = notes
        .map((n) => n.docNum.trim())
        .where((d) => d.isNotEmpty)
        .toList(growable: false);

    // Prefer first non-empty values across bulk-selected notes.
    String firstNonEmpty(String Function(DeliveryNote n) pick) {
      for (final n in notes) {
        final v = pick(n).trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    return ReceiptData(
      title: _salesTitle(notes),
      currency: first.docCurrency,
      docNo: '',
      orderNumbers: orderNumbers,
      customerName: first.bookingName.isNotEmpty
          ? first.bookingName
          : first.cardName,
      clientName: firstNonEmpty((n) => n.bookingName),
      agent: firstNonEmpty((n) => n.agent),
      wbNo: firstNonEmpty((n) => n.wbNo),
      waiter: firstNonEmpty((n) => n.waiter),
      room: first.rooming,
      tin: first.tinNo,
      bookingReference: first.trackingNumber,
      camp: ReceiptData.campFromCardName(first.cardName),
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMode: paymentMode,
      paidAmount: paidAmount,
      lines: lines,
    );
  }

  static ReceiptData fromInvoiceReceipt(InvoiceReceipt invoice) {
    final currency =
        invoice.docCurrency.trim().isEmpty ? 'USD' : invoice.docCurrency.trim();
    final lines = invoice.items
        .map(
          (item) => ReceiptLine(
            code: item.itemCode,
            name: item.description,
            qty: item.quantity,
            price: item.price,
          ),
        )
        .toList(growable: false);
    return ReceiptData(
      title: invoice.isDelivery ? 'Bar Order' : 'Sales Invoice',
      currency: currency,
      docNo: invoice.displayDocNo,
      customerName: invoice.bookingName.isNotEmpty
          ? invoice.bookingName
          : invoice.cardName,
      clientName: invoice.bookingName,
      agent: invoice.agent,
      wbNo: invoice.displayWbNo,
      waiter: invoice.waiter,
      room: invoice.rooming,
      tin: invoice.tinNo,
      bookingReference: invoice.displayWbNo,
      camp: ReceiptData.campFromCardName(invoice.cardName),
      subtotal: invoice.subtotal,
      tax: invoice.vatSum,
      total: invoice.docTotal,
      qrImageBase64: invoice.qrValue,
      lines: lines,
    );
  }

  /// Printed heading. Open sales rows are deliveries and print as Bar Order.
  static String _salesTitle(List<DeliveryNote> notes) {
    if (notes.isEmpty) return 'Sales Invoice';
    final deliveries = notes.where((n) => n.isDelivery).length;
    if (deliveries == notes.length) return 'Bar Order';
    if (deliveries == 0) return 'Sales Invoice';
    return notes.first.isDelivery ? 'Bar Order' : 'Sales Invoice';
  }
}
