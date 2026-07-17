import 'builtin_printer_service.dart';

bool get isSupported => false;

Future<bool> isAvailable() async => false;

Future<BuiltInPrinterInfo> getInfo() async => const BuiltInPrinterInfo();

Future<void> printBytes(List<int> bytes) async {
  throw UnsupportedError(
    'Built-in printer is only available on Android POS devices.',
  );
}
