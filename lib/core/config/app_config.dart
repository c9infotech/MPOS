class AppConfig {
  AppConfig({
    required this.apiUrl,
    required this.companyDb,
  });

  final String apiUrl;
  final String companyDb;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    // Match Vue config key `companydb` (also accept `companyDb`).
    final companyDb = (json['companydb'] ?? json['companyDb'] ?? 'KARIBU_CAMPS')
        .toString();
    return AppConfig(
      apiUrl: (json['apiUrl'] as String?) ?? 'http://default-url/api/',
      companyDb: companyDb,
    );
  }
}
