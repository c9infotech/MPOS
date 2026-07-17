import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared JSON POST used by IO and Web clients (axios-compatible shape).
Future<Map<String, dynamic>> postJsonRequest({
  required Uri uri,
  required Map<String, dynamic> body,
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.body.isEmpty) {
      throw Exception('Empty response from server.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format.');
    }
    return decoded;
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}
