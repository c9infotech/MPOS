class DeliveryNoteItem {
  DeliveryNoteItem({
    required this.itemCode,
    required this.description,
    required this.quantity,
    required this.price,
    required this.vatPercent,
    required this.whsCode,
    required this.baseType,
    required this.baseEntry,
    required this.baseLine,
    required this.charged,
  });

  final String itemCode;
  final String description;
  final double quantity;
  final double price;
  final double vatPercent;
  final String whsCode;
  final dynamic baseType;
  final dynamic baseEntry;
  final dynamic baseLine;
  final bool charged;

  factory DeliveryNoteItem.fromJson(Map<String, dynamic> json) {
    return DeliveryNoteItem(
      itemCode: (json['itemCode'] ?? '').toString(),
      description: (json['dscription'] ?? json['description'] ?? '').toString(),
      quantity: _toDouble(json['quantity']),
      price: _toDouble(json['price']),
      vatPercent: _toDouble(json['vatPercent']),
      whsCode: (json['whsCode'] ?? '').toString(),
      baseType: json['baseType'],
      baseEntry: json['baseEntry'],
      baseLine: json['baseLine'],
      charged: (json['u_Charged'] ?? '').toString().toUpperCase() == 'TRUE',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class DeliveryNote {
  DeliveryNote({
    required this.docNum,
    required this.cardCode,
    required this.cardName,
    required this.trackingNumber,
    required this.rooming,
    required this.bookingName,
    required this.docDate,
    required this.docDueDate,
    required this.docCurrency,
    required this.tinNo,
    required this.salespersonCode,
    required this.comments,
    required this.items,
    this.docDateRaw = '',
  });

  final String docNum;
  final String cardCode;
  final String cardName;
  final String trackingNumber;
  final String rooming;
  final String bookingName;
  final DateTime? docDate;
  final DateTime? docDueDate;
  final String docCurrency;
  final String tinNo;
  final String salespersonCode;
  final String comments;
  final List<DeliveryNoteItem> items;
  /// Original API date string (e.g. "9/8/2026 12:00:00 AM") for display fallback.
  final String docDateRaw;

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['deliveryNoteItemDetails'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => DeliveryNoteItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DeliveryNoteItem>[];

    final rawDate = (json['docDate'] ??
            json['DocDate'] ??
            json['taxDate'] ??
            json['TaxDate'] ??
            '')
        .toString()
        .trim();

    return DeliveryNote(
      docNum: (json['docNum'] ?? '').toString(),
      cardCode: (json['cardCode'] ?? '').toString(),
      cardName: (json['cardName'] ?? '').toString(),
      trackingNumber: (json['trackingNumber'] ?? '').toString(),
      rooming: (json['u_Rooming'] ?? '').toString(),
      bookingName: (json['u_BookingName'] ?? '').toString(),
      docDate: _parseDate(rawDate),
      docDueDate: _parseDate(json['docDueDate'] ?? json['DocDueDate']),
      docCurrency: (json['docCurrency'] ?? '').toString(),
      tinNo: (json['u_TINNo'] ?? '').toString(),
      salespersonCode: (json['salespersoncode'] ?? '').toString(),
      comments: (json['comments'] ?? '').toString(),
      items: items,
      docDateRaw: rawDate,
    );
  }

  /// Prefer parsed date; otherwise show the API date part (before time).
  String get docDateLabel {
    if (docDate != null) {
      final d = docDate!;
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }
    if (docDateRaw.isEmpty) return '-';
    return docDateRaw.split(RegExp(r'\s+')).first;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      final n = value.toInt();
      final ms = n > 9999999999 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    var raw = value.toString().trim();
    if (raw.isEmpty) return null;
    raw = raw
        .replaceAll('\u00a0', ' ')
        .replaceAll('／', '/')
        .replaceAll('⁄', '/');

    // SAP OData: /Date(1719792000000)/
    final sap = RegExp(r'/Date\((-?\d+)\)/').firstMatch(raw);
    if (sap != null) {
      final ms = int.tryParse(sap.group(1)!);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final spaced = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (spaced != null) return spaced;

    if (RegExp(r'^\d{8}$').hasMatch(raw)) {
      return DateTime(
        int.parse(raw.substring(0, 4)),
        int.parse(raw.substring(4, 6)),
        int.parse(raw.substring(6, 8)),
      );
    }

    // .NET: "9/8/2026 12:00:00 AM" or "9/8/2026"
    final datePart = raw.split(RegExp(r'\s+')).first;
    final mdy =
        RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(datePart);
    if (mdy != null) {
      final a = int.parse(mdy.group(1)!);
      final b = int.parse(mdy.group(2)!);
      final year = int.parse(mdy.group(3)!);
      // API uses US M/d/yyyy
      if (a >= 1 && a <= 12 && b >= 1 && b <= 31) {
        return DateTime(year, a, b);
      }
    }

    return null;
  }

  String get docDateIso {
    final d = docDate ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get docDueDateIso {
    final d = docDueDate ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  double get lineTotal {
    return items.fold<double>(0, (sum, i) => sum + (i.quantity * i.price));
  }

  double get taxTotal {
    return items.fold<double>(0, (sum, i) {
      final top = i.quantity * i.price;
      return sum + (top * i.vatPercent / 100);
    });
  }

  double get grandTotal => lineTotal + taxTotal;
}
