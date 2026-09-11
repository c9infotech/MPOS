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
    this.orderNumbers = const [],
    this.customerName = '',
    this.clientName = '',
    this.agent = '',
    this.wbNo = '',
    this.waiter = '',
    this.room = '',
    this.tin = '',
    this.bookingReference = '',
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
  /// Delivery / sales doc numbers shown at the bottom as Order Number's.
  final List<String> orderNumbers;
  final String customerName;
  /// From `U_BookingName`.
  final String clientName;
  /// From `u_Agent` / Agent.
  final String agent;
  /// From `u_WBNO` / wbnNo.
  final String wbNo;
  /// From `BranchEmpName` / Waiter.
  final String waiter;
  final String room;
  final String tin;
  final String bookingReference;
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
