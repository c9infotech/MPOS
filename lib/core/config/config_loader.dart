import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_config.dart';
import 'startup_debug.dart';
import '../storage/safe_shared_preferences.dart';

class ConfigLoader {
  ConfigLoader._();

  static const _assetPath = 'assets/config.json';
  static AppConfig? _config;
  static ConfigLoadDiagnostics? lastDiagnostics;

  static Future<AppConfig> load() async {
    if (_config != null) return _config!;
    String raw;
    try {
      raw = await rootBundle.loadString(_assetPath);
    } catch (e, stack) {
      throw StartupDebugException(
        StartupDebugReport(
          failedStep: 'Load asset bundle ($_assetPath)',
          error: e,
          stackTrace: stack,
          configDiagnostics: ConfigLoadDiagnostics(
            assetPath: _assetPath,
            rawLength: 0,
            firstBytesHex: '(could not read asset)',
            bomHint: 'Asset missing or bundle not loaded — copy full Release folder',
            firstCharCode: null,
            startsWithBrace: false,
            preview: '(unavailable)',
          ),
        ),
      );
    }

    lastDiagnostics = ConfigLoadDiagnostics.analyze(_assetPath, raw);
    ConfigLoaderBridge.lastDiagnostics = lastDiagnostics;

    try {
      _config = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _config!;
    } catch (e, stack) {
      throw StartupDebugException(
        StartupDebugReport(
          failedStep: 'Parse JSON ($_assetPath)',
          error: e,
          stackTrace: stack,
          configDiagnostics: lastDiagnostics,
        ),
      );
    }
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
