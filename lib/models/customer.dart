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
    this.agent = '',
    this.clientName = '',
    this.wbnNo = '',
    this.cashSalesNo = '',
    this.waiter = '',
  });

  final String cardCode;
  final String cardName;
  /// Legacy display / booking name; prefer [clientName] when set.
  String customerName;
  String tin;
  final String currency;
  String room;
  /// Legacy booking/reference; prefer [wbnNo] when set.
  String contact;
  final String whsCode;
  String agent;
  String clientName;
  String wbnNo;
  String cashSalesNo;
  String waiter;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final cardName = (json['cardName'] ?? '').toString();
    final clientName = (json['clientName'] ?? '').toString();
    final customerName = (json['customerName'] ?? '').toString();
    final wbnNo = (json['wbnNo'] ?? json['WBNNo'] ?? '').toString();
    final contact = (json['contact'] ?? json['reference2'] ?? '').toString();
    return Customer(
      cardCode: (json['cardCode'] ?? '').toString(),
      // Account / cash-sales name — never used to fill clientName.
      cardName: cardName.isNotEmpty ? cardName : customerName,
      // Keep legacy booking field separate from cardName; do not copy cardName.
      customerName: customerName,
      tin: (json['tinNo'] ?? json['tin'] ?? json['u_TINNo'] ?? '').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      room: (json['roomNo'] ?? json['room'] ?? json['u_Rooming'] ?? '')
          .toString(),
      contact: contact.isNotEmpty ? contact : wbnNo,
      whsCode: (json['whsCode'] ?? '').toString(),
      agent: (json['agent'] ?? '').toString(),
      // Only API clientName — never fall back to cardName.
      clientName: clientName,
      wbnNo: wbnNo.isNotEmpty ? wbnNo : contact,
      cashSalesNo: (json['cashSalesNo'] ?? '').toString(),
      waiter: (json['BranchEmpName'] ??
              json['branchEmpName'] ??
              json['waiter'] ??
              json['Waiter'] ??
              json['u_Waiter'] ??
              '')
          .toString(),
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
      agent: agent,
      clientName: clientName,
      wbnNo: wbnNo,
      cashSalesNo: cashSalesNo,
      waiter: waiter,
    );
  }
}
