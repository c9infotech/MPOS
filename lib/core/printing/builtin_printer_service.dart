import 'builtin_printer_io.dart'
    if (dart.library.html) 'builtin_printer_stub.dart' as impl;

class BuiltInPrinterInfo {
  const BuiltInPrinterInfo({
    this.status,
    this.version,
    this.paper,
    this.type,
    this.id,
  });

  final String? status;
  final String? version;
  final String? paper;
  final String? type;
  final String? id;

  bool get detected =>
      (status != null && status!.isNotEmpty) ||
      (type != null && type!.isNotEmpty) ||
      (id != null && id!.isNotEmpty);
}

/// Built-in Android POS thermal printer (Sunmi inner printer service).
abstract final class BuiltInPrinterService {
  static bool get isSupported => impl.isSupported;

  static Future<bool> isAvailable() => impl.isAvailable();

  static Future<BuiltInPrinterInfo> getInfo() => impl.getInfo();

  static Future<void> printBytes(List<int> bytes) => impl.printBytes(bytes);
}
