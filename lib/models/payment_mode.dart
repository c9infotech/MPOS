class PaymentMode {
  PaymentMode({
    required this.paymentMode,
    required this.branch,
    this.code,
  });

  final String paymentMode;
  final String branch;
  final String? code;

  factory PaymentMode.fromJson(Map<String, dynamic> json) {
    return PaymentMode(
      paymentMode: (json['paymentMode'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      code: json['code']?.toString(),
    );
  }
}
