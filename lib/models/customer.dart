class Customer {
  Customer({
    required this.cardCode,
    required this.cardName,
    required this.customerName,
    required this.tin,
    required this.currency,
    required this.room,
    required this.contact,
    required this.whsCode,
  });

  final String cardCode;
  final String cardName;
  String customerName;
  String tin;
  final String currency;
  String room;
  String contact;
  final String whsCode;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final name = (json['customerName'] ?? json['cardName'] ?? '').toString();
    return Customer(
      cardCode: (json['cardCode'] ?? '').toString(),
      cardName: (json['cardName'] ?? name).toString(),
      customerName: name,
      tin: (json['tin'] ?? json['u_TINNo'] ?? '').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      room: (json['room'] ?? json['u_Rooming'] ?? '').toString(),
      contact: (json['contact'] ?? json['reference2'] ?? '').toString(),
      whsCode: (json['whsCode'] ?? '').toString(),
    );
  }

  Customer copy() {
    return Customer(
      cardCode: cardCode,
      cardName: cardName,
      customerName: customerName,
      tin: tin,
      currency: currency,
      room: room,
      contact: contact,
      whsCode: whsCode,
    );
  }
}
