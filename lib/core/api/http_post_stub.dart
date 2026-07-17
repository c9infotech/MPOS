import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> platformPostJson({
  required Uri uri,
  required Map<String, dynamic> body,
  http.Client? client,
}) {
  throw UnsupportedError('No platform HTTP implementation available.');
}
