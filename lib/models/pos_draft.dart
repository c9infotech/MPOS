import 'dart:convert';

import 'customer.dart';
import 'product.dart';

class PosDraftSlot {
  const PosDraftSlot({
    required this.tableNumber,
    required this.subdivision,
  });

  final int tableNumber;
  final String subdivision;

  String get label => 'Table $tableNumber · $subdivision';

  Map<String, dynamic> toJson() => {
        'tableNumber': tableNumber,
        'subdivision': subdivision,
      };

  factory PosDraftSlot.fromJson(Map<String, dynamic> json) => PosDraftSlot(
        tableNumber: (json['tableNumber'] as num).toInt(),
        subdivision: json['subdivision'] as String,
      );
}

class SavedPosDraft {
  SavedPosDraft({
    required this.id,
    required this.slot,
    required this.lines,
    required this.currency,
    required this.savedAt,
    this.customer,
  });

  final String id;
  final PosDraftSlot slot;
  final List<CartLine> lines;
  final String currency;
  final DateTime savedAt;
  final Customer? customer;

  int get itemCount => lines.fold<int>(0, (s, l) => s + l.qty);

  double get subtotal => lines.fold<double>(
        0,
        (s, l) => s + (l.chargeable ? l.cartPrice * l.qty : 0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slot': slot.toJson(),
        'lines': lines.map(_cartLineToJson).toList(),
        'currency': currency,
        'savedAt': savedAt.toIso8601String(),
        'customer': customer == null
            ? null
            : {
                'cardCode': customer!.cardCode,
                'cardName': customer!.cardName,
                'customerName': customer!.customerName,
                'tin': customer!.tin,
                'currency': customer!.currency,
                'room': customer!.room,
                'contact': customer!.contact,
                'whsCode': customer!.whsCode,
              },
      };

  factory SavedPosDraft.fromJson(Map<String, dynamic> json) {
    Customer? customer;
    final customerJson = json['customer'];
    if (customerJson is Map<String, dynamic>) {
      customer = Customer.fromJson(customerJson);
    }
    return SavedPosDraft(
      id: json['id'] as String,
      slot: PosDraftSlot.fromJson(json['slot'] as Map<String, dynamic>),
      lines: (json['lines'] as List)
          .map((e) => _cartLineFromJson(e as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String? ?? 'USD',
      savedAt: DateTime.parse(json['savedAt'] as String),
      customer: customer,
    );
  }
}

class RestoredCart {
  const RestoredCart({
    required this.lines,
    required this.currency,
    this.customer,
  });

  final List<CartLine> lines;
  final String currency;
  final Customer? customer;
}

Map<String, dynamic> _cartLineToJson(CartLine line) => {
      'product': {
        'itemCode': line.product.itemCode,
        'itemName': line.product.itemName,
        'salUnitMsr': line.product.salUnitMsr,
        'uomName': line.product.uomName,
        'usdPrice': line.product.usdPrice,
        'tzsPrice': line.product.tzsPrice,
        'usduomPrice': line.product.usduomPrice,
        'tzsuomPrice': line.product.tzsuomPrice,
        'qtyPerUom': line.product.qtyPerUom,
        'itemUom': line.product.itemUom,
        'isPriceEditable': line.product.isPriceEditable,
        'image': line.product.image,
      },
      'qty': line.qty,
      'cartPrice': line.cartPrice,
      'cartUom': line.cartUom,
      'chargeable': line.chargeable,
      'withGst': line.withGst,
    };

CartLine _cartLineFromJson(Map<String, dynamic> json) {
  final productJson = json['product'] as Map<String, dynamic>;
  return CartLine(
    product: Product.fromJson(productJson),
    qty: (json['qty'] as num).toInt(),
    cartPrice: (json['cartPrice'] as num).toDouble(),
    cartUom: json['cartUom'] as String,
    chargeable: json['chargeable'] as bool? ?? true,
    withGst: (json['withGst'] as num?)?.toDouble() ?? 0,
  );
}

List<CartLine> cloneCartLines(List<CartLine> lines) {
  return lines
      .map(
        (l) => CartLine(
          product: Product(
            itemCode: l.product.itemCode,
            itemName: l.product.itemName,
            salUnitMsr: l.product.salUnitMsr,
            uomName: l.product.uomName,
            usdPrice: l.product.usdPrice,
            tzsPrice: l.product.tzsPrice,
            usduomPrice: l.product.usduomPrice,
            tzsuomPrice: l.product.tzsuomPrice,
            qtyPerUom: l.product.qtyPerUom,
            itemUom: l.product.itemUom,
            isPriceEditable: l.product.isPriceEditable,
            image: l.product.image,
          ),
          qty: l.qty,
          cartPrice: l.cartPrice,
          cartUom: l.cartUom,
          chargeable: l.chargeable,
          withGst: l.withGst,
        ),
      )
      .toList();
}

String encodePosDraftList(List<SavedPosDraft> drafts) =>
    jsonEncode(drafts.map((d) => d.toJson()).toList());

List<SavedPosDraft> decodePosDraftList(String raw) {
  final list = jsonDecode(raw) as List;
  return list
      .map((e) => SavedPosDraft.fromJson(e as Map<String, dynamic>))
      .toList();
}
