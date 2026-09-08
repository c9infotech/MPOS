class Product {
  Product({
    required this.itemCode,
    required this.itemName,
    required this.salUnitMsr,
    required this.uomName,
    required this.usdPrice,
    required this.tzsPrice,
    required this.usduomPrice,
    required this.tzsuomPrice,
    required this.qtyPerUom,
    required this.itemUom,
    required this.isPriceEditable,
    required this.isPremiumDrink,
    this.type = '',
    this.image,
  });

  static const othersCategory = 'Others';

  final String itemCode;
  final String itemName;
  final String salUnitMsr;
  final String uomName;
  final double usdPrice;
  final double tzsPrice;
  final double usduomPrice;
  final double tzsuomPrice;
  final String qtyPerUom;
  final String itemUom;
  final bool isPriceEditable;
  /// From API `premiumDrinks`: Y = chargeable locked on.
  final bool isPremiumDrink;
  /// Product type used for POS category chips.
  final String type;
  final String? image;

  /// Category chip label: [type] when set, otherwise [othersCategory].
  String get categoryLabel {
    final t = type.trim();
    return t.isEmpty ? othersCategory : t;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemCode: (json['itemCode'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      salUnitMsr: (json['salUnitMsr'] ?? '').toString(),
      uomName: (json['uomName'] ?? '').toString(),
      usdPrice: _toDouble(json['usdPrice']),
      tzsPrice: _toDouble(json['tzsPrice']),
      usduomPrice: _toDouble(json['usduomPrice']),
      tzsuomPrice: _toDouble(json['tzsuomPrice']),
      qtyPerUom: (json['qtyPerUom'] ?? '').toString(),
      itemUom: (json['itemUOM'] ?? json['itemUom'] ?? '').toString(),
      isPriceEditable: (json['isPriceEditable'] ?? 'N').toString() == 'Y',
      isPremiumDrink: (json['premiumDrinks'] ?? 'N').toString() == 'Y',
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      image: json['image']?.toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class CartLine {
  CartLine({
    required this.product,
    required this.qty,
    required this.cartPrice,
    required this.cartUom,
    required this.chargeable,
    this.isDelivered = false,
    this.withGst = 0,
  });

  final Product product;
  int qty;
  double cartPrice;
  String cartUom;
  bool chargeable;
  bool isDelivered;
  double withGst;
}
