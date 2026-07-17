import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_config.dart';

class ConfigLoader {
  ConfigLoader._();

  static AppConfig? _config;

  static Future<AppConfig> load() async {
    if (_config != null) return _config!;
    final raw = await rootBundle.loadString('assets/config.json');
    _config = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _config!;
  }

  static void setForTesting(AppConfig config) {
    _config = config;
  }

  static AppConfig get current {
    final config = _config;
    if (config == null) {
      throw StateError('AppConfig has not been loaded yet.');
    }
    return config;
  }

  static String get apiUrl => current.apiUrl;
}
