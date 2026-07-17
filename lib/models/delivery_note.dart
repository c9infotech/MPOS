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

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['deliveryNoteItemDetails'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(DeliveryNoteItem.fromJson)
            .toList()
        : <DeliveryNoteItem>[];

    return DeliveryNote(
      docNum: (json['docNum'] ?? '').toString(),
      cardCode: (json['cardCode'] ?? '').toString(),
      cardName: (json['cardName'] ?? '').toString(),
      trackingNumber: (json['trackingNumber'] ?? '').toString(),
      rooming: (json['u_Rooming'] ?? '').toString(),
      bookingName: (json['u_BookingName'] ?? '').toString(),
      docDate: DateTime.tryParse((json['docDate'] ?? '').toString()),
      docDueDate: DateTime.tryParse((json['docDueDate'] ?? '').toString()),
      docCurrency: (json['docCurrency'] ?? '').toString(),
      tinNo: (json['u_TINNo'] ?? '').toString(),
      salespersonCode: (json['salespersoncode'] ?? '').toString(),
      comments: (json['comments'] ?? '').toString(),
      items: items,
    );
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
