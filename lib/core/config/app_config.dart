class AppConfig {
  AppConfig({
    required this.apiUrl,
    required this.companyDbs,
  });

  final String apiUrl;
  final List<String> companyDbs;

  /// Default / first company DB (login fallback & API default).
  String get companyDb =>
      companyDbs.isNotEmpty ? companyDbs.first : 'KARIBU_CAMPS';

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    // Accept string or list under `companydb` / `companyDb` / `companydbs`.
    final raw = json['companydbs'] ?? json['companydb'] ?? json['companyDb'];
    final companyDbs = _parseCompanyDbs(raw);
    return AppConfig(
      apiUrl: (json['apiUrl'] as String?) ?? 'http://default-url/api/',
      companyDbs: companyDbs,
    );
  }

  static List<String> _parseCompanyDbs(dynamic raw) {
    if (raw is List) {
      final list = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } else if (raw != null) {
      final value = raw.toString().trim();
      if (value.isNotEmpty) return [value];
    }
    return const ['KARIBU_CAMPS'];
  }
}
