import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/config_loader.dart';
import 'http_post_stub.dart'
    if (dart.library.html) 'http_post_web.dart'
    if (dart.library.io) 'http_post_io.dart' as platform_http;

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String endpoint) {
    final base = ConfigLoader.apiUrl;
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse('$normalized$endpoint');
  }

  Future<Map<String, dynamic>> post(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = _uri(endpoint);
    final payload = body ?? <String, dynamic>{};
    try {
      return await platform_http.platformPostJson(
        uri: uri,
        body: payload,
        client: _client,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  static String extractError(Map<String, dynamic> data) {
    final statusMessage = data['statusMessage']?.toString();
    final responseData = data['responseData'];

    String? detail;
    if (responseData is String && responseData.isNotEmpty) {
      detail = responseData;
    } else if (responseData is Map<String, dynamic>) {
      final error = responseData['error'];
      if (error is String && error.isNotEmpty) {
        try {
          final parsed = jsonDecode(error);
          if (parsed is Map && parsed['value'] != null) {
            detail = parsed['value'].toString();
          } else {
            detail = error;
          }
        } catch (_) {
          detail = error;
        }
      }
    }

    if (statusMessage != null &&
        statusMessage.isNotEmpty &&
        detail != null &&
        detail.isNotEmpty &&
        statusMessage != detail) {
      return '$statusMessage: $detail';
    }
    if (detail != null && detail.isNotEmpty) return detail;
    if (statusMessage != null && statusMessage.isNotEmpty) return statusMessage;
    return 'Something went wrong!';
  }
}
