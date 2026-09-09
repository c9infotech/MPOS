import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession({
    required this.uiJson,
    required this.database,
    required this.timestamp,
    this.apiUrl = '',
  });

  final Map<String, dynamic> uiJson;
  final String database;
  final int timestamp;
  final String apiUrl;

  String? get sessionId => uiJson['sessionId']?.toString();

  String get employeeId {
    final raw = uiJson['employeeId']?.toString();
    if (raw != null && raw.isNotEmpty) return raw;
    return userCode;
  }

  String get userCode {
    final userList = uiJson['userList'];
    if (userList is Map<String, dynamic>) {
      final responseData = userList['responseData'];
      if (responseData is List && responseData.isNotEmpty) {
        final first = responseData.first;
        if (first is Map<String, dynamic>) {
          return first['userCode']?.toString() ?? '';
        }
      }
    }
    return '';
  }
}

class AuthService {
  AuthService(this._prefs);

  final SharedPreferences _prefs;

  static const _uiKey = 'UI';
  static const _authKey = 'authToken';
  static const _dbKey = 'db';
  static const _apiUrlKey = 'apiUrl';
  static const _authTtlMs = 60 * 60 * 1000;

  bool get isAuthenticated {
    final raw = _prefs.getString(_authKey);
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - timestamp > _authTtlMs) {
        clearSession();
        return false;
      }
      return _prefs.getString(_uiKey) != null;
    } catch (_) {
      return false;
    }
  }

  AuthSession? get session {
    if (!isAuthenticated) return null;
    final uiRaw = _prefs.getString(_uiKey);
    final db = _prefs.getString(_dbKey) ?? '';
    final apiUrl = _prefs.getString(_apiUrlKey) ?? '';
    final authRaw = _prefs.getString(_authKey);
    if (uiRaw == null || authRaw == null) return null;
    final auth = jsonDecode(authRaw) as Map<String, dynamic>;
    return AuthSession(
      uiJson: jsonDecode(uiRaw) as Map<String, dynamic>,
      database: db,
      timestamp: auth['timestamp'] as int? ?? 0,
      apiUrl: apiUrl,
    );
  }

  Future<void> saveSession({
    required Map<String, dynamic> ui,
    required String database,
    String? apiUrl,
  }) async {
    await _prefs.setString(_uiKey, jsonEncode(ui));
    await _prefs.setString(_dbKey, database);
    if (apiUrl != null && apiUrl.trim().isNotEmpty) {
      await _prefs.setString(_apiUrlKey, apiUrl.trim());
    } else {
      await _prefs.remove(_apiUrlKey);
    }
    await _prefs.setString(
      _authKey,
      jsonEncode({
        'token': 'mpos-session',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> clearSession() async {
    await _prefs.remove(_uiKey);
    await _prefs.remove(_authKey);
    await _prefs.remove(_dbKey);
    await _prefs.remove(_apiUrlKey);
  }
}
