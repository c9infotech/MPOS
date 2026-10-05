class InvoiceReceiptItem {
  const InvoiceReceiptItem({
    required this.lineNum,
    required this.itemCode,
    required this.description,
    required this.quantity,
    required this.price,
    required this.lineTotal,
    this.vatPercent = 0,
  });

  final String lineNum;
  final String itemCode;
  final String description;
  final double quantity;
  final double price;
  final double lineTotal;
  final double vatPercent;

  factory InvoiceReceiptItem.fromJson(Map<String, dynamic> json) {
    return InvoiceReceiptItem(
      lineNum: (json['LineNum'] ?? json['lineNum'] ?? '').toString(),
      itemCode: (json['ItemCode'] ?? json['itemCode'] ?? '').toString(),
      description: (json['Dscription'] ??
              json['dscription'] ??
              json['description'] ??
              json['ItemName'] ??
              '')
          .toString(),
      quantity: _toDouble(json['Quantity'] ?? json['quantity']),
      price: _toDouble(json['Price'] ?? json['price']),
      lineTotal: _toDouble(json['LineTotal'] ?? json['lineTotal']),
      vatPercent: _toDouble(json['VATPercent'] ?? json['vatPercent']),
    );
  }
}

class InvoiceReceipt {
  InvoiceReceipt({
    this.docType = 'Invoice',
    required this.docEntry,
    required this.docNum,
    required this.cardCode,
    required this.cardName,
    required this.docDate,
    required this.docTotal,
    required this.vatSum,
    required this.docCurrency,
    required this.items,
    this.seriesName = '',
    this.numAtCard = '',
    this.wbNo = '',
    this.agent = '',
    this.bookingName = '',
    this.tinNo = '',
    this.rooming = '',
    this.waiter = '',
    this.qrValue = '',
  });

  final String docType;
  final String docEntry;
  final String docNum;
  final String seriesName;
  final String cardCode;
  final String cardName;
  final String docDate;
  final double docTotal;
  final double vatSum;
  final String docCurrency;
  final String numAtCard;
  final String wbNo;
  final String agent;
  final String bookingName;
  final String tinNo;
  final String rooming;
  final String waiter;
  /// SAP UDF `U_QRValue` — often `data:image/jpg;base64,...`.
  final String qrValue;
  final List<InvoiceReceiptItem> items;

  String get displayDocNo {
    final series = seriesName.trim();
    final num = docNum.trim();
    if (series.isEmpty) return num;
    if (num.isEmpty) return series;
    return '$series $num';
  }

  String get displayWbNo => wbNo.trim();

  bool get isDelivery => docType.trim().toLowerCase() == 'delivery';

  String get displayDocType => isDelivery ? 'Delivery' : 'Invoice';

  double get subtotal {
    final s = docTotal - vatSum;
    return s < 0 ? 0 : s;
  }

  factory InvoiceReceipt.fromJson(Map<String, dynamic> json) {
    final rawItems = json['Items'] ?? json['items'] ?? json['InvoiceItems'];
    final items = <InvoiceReceiptItem>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is Map<String, dynamic>) {
          items.add(InvoiceReceiptItem.fromJson(row));
        } else if (row is Map) {
          items.add(
            InvoiceReceiptItem.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }
    return InvoiceReceipt(
      docType: (json['DocType'] ?? json['docType'] ?? 'Invoice').toString(),
      docEntry: (json['DocEntry'] ?? json['docEntry'] ?? '').toString(),
      docNum: (json['DocNum'] ?? json['docNum'] ?? '').toString(),
      seriesName: (json['SeriesName'] ?? json['seriesName'] ?? '').toString(),
      cardCode: (json['CardCode'] ?? json['cardCode'] ?? '').toString(),
      cardName: (json['CardName'] ?? json['cardName'] ?? '').toString(),
      docDate: (json['DocDate'] ?? json['docDate'] ?? '').toString(),
      docTotal: _toDouble(json['DocTotal'] ?? json['docTotal']),
      vatSum: _toDouble(json['VatSum'] ?? json['vatSum']),
      docCurrency:
          (json['DocCurrency'] ?? json['docCurrency'] ?? json['DocCur'] ?? 'USD')
              .toString(),
      numAtCard: (json['NumAtCard'] ?? json['numAtCard'] ?? '').toString(),
      wbNo: (json['WBno'] ??
              json['wBno'] ??
              json['WbnNo'] ??
              json['wbNo'] ??
              json['U_WBNo'] ??
              '')
          .toString(),
      agent: (json['Agent'] ?? json['agent'] ?? '').toString(),
      bookingName:
          (json['BookingName'] ?? json['bookingName'] ?? json['U_BookingName'] ?? '')
              .toString(),
      tinNo: (json['TINNo'] ?? json['tinNo'] ?? json['U_TINNo'] ?? '').toString(),
      rooming:
          (json['Rooming'] ?? json['rooming'] ?? json['U_Rooming'] ?? '')
              .toString(),
      waiter: (json['Waiter'] ?? json['waiter'] ?? '').toString(),
      qrValue: (json['QRValue'] ?? json['qrValue'] ?? json['U_QRValue'] ?? '')
          .toString(),
      items: items,
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
}
