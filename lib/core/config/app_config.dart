class CompanyDbEntry {
  const CompanyDbEntry({
    required this.name,
    required this.apiUrl,
  });

  final String name;
  final String apiUrl;
}

class AppConfig {
  AppConfig({
    required this.apiUrl,
    required this.companies,
  });

  /// Fallback base URL when a company has no override.
  final String apiUrl;
  final List<CompanyDbEntry> companies;

  /// Company names for login dropdown.
  List<String> get companyDbs =>
      companies.map((c) => c.name).toList(growable: false);

  /// Default / first company DB (login fallback & API default).
  String get companyDb =>
      companies.isNotEmpty ? companies.first.name : 'KARIBU_CAMPS';

  String apiUrlForCompany(String companyDb) {
    final key = companyDb.trim();
    for (final c in companies) {
      if (c.name == key) return c.apiUrl;
    }
    return apiUrl;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final defaultApiUrl =
        (json['apiUrl'] as String?)?.trim().isNotEmpty == true
            ? (json['apiUrl'] as String).trim()
            : 'http://default-url/api/';

    final raw = json['companydbs'] ?? json['companydb'] ?? json['companyDb'];
    final companies = _parseCompanies(raw, defaultApiUrl);

    return AppConfig(
      apiUrl: defaultApiUrl,
      companies: companies,
    );
  }

  static List<CompanyDbEntry> _parseCompanies(
    dynamic raw,
    String defaultApiUrl,
  ) {
    if (raw is List) {
      final list = <CompanyDbEntry>[];
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final name = (map['name'] ??
                  map['companydb'] ??
                  map['companyDb'] ??
                  map['db'] ??
                  '')
              .toString()
              .trim();
          if (name.isEmpty) continue;
          final url = (map['apiUrl'] ?? map['baseUrl'] ?? defaultApiUrl)
              .toString()
              .trim();
          list.add(CompanyDbEntry(
            name: name,
            apiUrl: url.isEmpty ? defaultApiUrl : url,
          ));
        } else {
          final name = item.toString().trim();
          if (name.isEmpty) continue;
          list.add(CompanyDbEntry(name: name, apiUrl: defaultApiUrl));
        }
      }
      if (list.isNotEmpty) return list;
    } else if (raw != null) {
      final name = raw.toString().trim();
      if (name.isNotEmpty) {
        return [CompanyDbEntry(name: name, apiUrl: defaultApiUrl)];
      }
    }
    return [
      CompanyDbEntry(name: 'KARIBU_CAMPS', apiUrl: defaultApiUrl),
    ];
  }
}
