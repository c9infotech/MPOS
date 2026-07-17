import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_post.dart';

/// Non-web (mobile/desktop) POST using package:http.
Future<Map<String, dynamic>> platformPostJson({
  required Uri uri,
  required Map<String, dynamic> body,
  http.Client? client,
}) {
  return postJsonRequest(uri: uri, body: body, client: client);
}

String encodeBody(Map<String, dynamic> body) => jsonEncode(body);
