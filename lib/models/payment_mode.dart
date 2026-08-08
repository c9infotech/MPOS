class PaymentMode {
  PaymentMode({
    required this.paymentMode,
    required this.branch,
    this.code,
    this.customerCode,
  });

  final String paymentMode;
  final String branch;
  final String? code;
  final String? customerCode;

  factory PaymentMode.fromJson(Map<String, dynamic> json) {
    return PaymentMode(
      paymentMode: (json['paymentMode'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      code: json['code']?.toString(),
      customerCode: (json['CustomerCode'] ?? json['customerCode'])?.toString(),
    );
  }

  /// True when this mode belongs to [cardCode] (sale customer).
  bool matchesCustomer(String cardCode) {
    final modeCode = (customerCode ?? '').trim();
    final saleCode = cardCode.trim();
    if (modeCode.isEmpty || saleCode.isEmpty) return false;
    return modeCode.toLowerCase() == saleCode.toLowerCase();
  }
}
