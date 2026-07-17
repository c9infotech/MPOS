import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web POST using browser XHR — same transport style as Vue/axios.
Future<Map<String, dynamic>> platformPostJson({
  required Uri uri,
  required Map<String, dynamic> body,
  http.Client? client,
}) async {
  final completer = Completer<Map<String, dynamic>>();
  final xhr = html.HttpRequest();

  xhr.open('POST', uri.toString(), async: true);
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.setRequestHeader('Accept', 'application/json');
  xhr.withCredentials = false;

  xhr.onLoad.listen((_) {
    final status = xhr.status ?? 0;
    final responseText = xhr.responseText ?? '';
    if (status < 200 || status >= 300) {
      completer.completeError(
        Exception('HTTP $status: ${responseText.isEmpty ? 'Request failed' : responseText}'),
      );
      return;
    }
    if (responseText.isEmpty) {
      completer.completeError(Exception('Empty response from server.'));
      return;
    }
    try {
      final decoded = jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) {
        completer.completeError(Exception('Unexpected response format.'));
        return;
      }
      completer.complete(decoded);
    } catch (e) {
      completer.completeError(e);
    }
  });

  xhr.onError.listen((_) {
    completer.completeError(
      Exception(
        'Network error calling $uri. '
        'Check CORS on the API or that the server is reachable.',
      ),
    );
  });

  xhr.onTimeout.listen((_) {
    completer.completeError(Exception('Request timed out.'));
  });

  xhr.timeout = 60000;
  xhr.send(jsonEncode(body));

  return completer.future;
}
