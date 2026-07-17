class ReceiptLine {
  const ReceiptLine({
    required this.code,
    required this.name,
    required this.qty,
    required this.price,
    this.uom = '',
  });

  final String code;
  final String name;
  final double qty;
  final double price;
  final String uom;

  double get lineTotal => qty * price;
}

class ReceiptData {
  const ReceiptData({
    required this.title,
    required this.currency,
    required this.lines,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.docNo = '',
    this.customerName = '',
    this.room = '',
    this.tin = '',
    this.paymentMode = '',
    this.paidAmount,
    this.footer = 'Customer Sign:',
    this.printedAt,
  });

  final String title;
  final String currency;
  final List<ReceiptLine> lines;
  final double subtotal;
  final double tax;
  final double total;
  final String docNo;
  final String customerName;
  final String room;
  final String tin;
  final String paymentMode;
  final double? paidAmount;
  final String footer;
  final DateTime? printedAt;
}
