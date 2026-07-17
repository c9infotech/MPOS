import 'bluetooth_printer_io.dart'
    if (dart.library.html) 'bluetooth_printer_stub.dart' as impl;

class PrinterDeviceInfo {
  const PrinterDeviceInfo({required this.name, required this.macAddress});

  final String name;
  final String macAddress;
}

/// Platform-agnostic Bluetooth printer API.
abstract final class BluetoothPrinterService {
  static bool get isSupported => impl.isSupported;

  static Future<String?> getSavedPrinterMac() => impl.getSavedPrinterMac();

  static Future<String?> getSavedPrinterName() => impl.getSavedPrinterName();

  static Future<void> savePrinter({
    required String name,
    required String macAddress,
  }) =>
      impl.savePrinter(name: name, macAddress: macAddress);

  static Future<void> clearSavedPrinter() => impl.clearSavedPrinter();

  static Future<bool> ensurePermissions() => impl.ensurePermissions();

  static Future<bool> isBluetoothOn() => impl.isBluetoothOn();

  static Future<List<PrinterDeviceInfo>> pairedDevices() =>
      impl.pairedDevices();

  static Future<bool> connect(String macAddress) => impl.connect(macAddress);

  static Future<bool> isConnected() => impl.isConnected();

  static Future<void> disconnect() => impl.disconnect();

  static Future<void> printBytes(List<int> bytes) => impl.printBytes(bytes);
}
