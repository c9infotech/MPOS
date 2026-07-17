import 'bluetooth_printer_service.dart';

bool get isSupported => false;

Future<String?> getSavedPrinterMac() async => null;

Future<String?> getSavedPrinterName() async => null;

Future<void> savePrinter({
  required String name,
  required String macAddress,
}) async {}

Future<void> clearSavedPrinter() async {}

Future<bool> ensurePermissions() async => false;

Future<bool> isBluetoothOn() async => false;

Future<List<PrinterDeviceInfo>> pairedDevices() async => const [];

Future<bool> connect(String macAddress) async => false;

Future<bool> isConnected() async => false;

Future<void> disconnect() async {}

Future<void> printBytes(List<int> bytes) async {
  throw UnsupportedError(
    'Bluetooth thermal printing is not available on web. Use an Android/iOS device.',
  );
}
