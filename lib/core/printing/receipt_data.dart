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
    this.camp = '',
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
  /// Camp name from CS (cash sales) document / customer card name.
  final String camp;
  final String paymentMode;
  final double? paidAmount;
  final String footer;
  final DateTime? printedAt;

  /// Extracts camp from CS card names like "cash sales Lion's Paw- USD".
  static String campFromCardName(String cardName) {
    var text = cardName.trim();
    if (text.isEmpty) return '';

    final lower = text.toLowerCase();
    if (lower.startsWith('cash sales')) {
      text = text.substring('cash sales'.length).trim();
    } else if (lower.startsWith('cash sale')) {
      text = text.substring('cash sale'.length).trim();
    }

    text = text
        .replaceAll(RegExp(r'[\s\-]*\b(USD|TZS)\b\s*$', caseSensitive: false), '')
        .trim();
    text = text.replaceAll(RegExp(r'[-\s]+$'), '').trim();
    return text;
  }
}
