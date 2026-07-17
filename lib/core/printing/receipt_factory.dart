import '../../models/customer.dart';
import '../../models/delivery_note.dart';
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
    return ReceiptData(
      title: 'Delivery Note',
      currency: currency,
      docNo: docNo,
      customerName: customer.customerName.isNotEmpty
          ? customer.customerName
          : customer.cardName,
      room: customer.room,
      tin: customer.tin,
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
    final docNos = notes.map((n) => n.docNum).where((d) => d.isNotEmpty).join(', ');

    return ReceiptData(
      title: 'Sales Receipt',
      currency: first.docCurrency,
      docNo: docNos,
      customerName: first.bookingName.isNotEmpty
          ? first.bookingName
          : first.cardName,
      room: first.rooming,
      tin: first.tinNo,
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMode: paymentMode,
      paidAmount: paidAmount,
      lines: lines,
    );
  }
}
