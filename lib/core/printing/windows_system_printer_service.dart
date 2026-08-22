import 'windows_system_printer_stub.dart'
    if (dart.library.io) 'windows_system_printer_io.dart' as impl;
import 'windows_printer_paper_info.dart';

/// Prints ESC/POS bytes to an installed Windows system printer (USB/driver).
abstract final class WindowsSystemPrinterService {
  static bool get isSupported => impl.isSupported;

  static Future<List<String>> listPrinters() => impl.listPrinters();

  static Future<String?> getDefaultPrinterName() =>
      impl.getDefaultPrinterName();

  static Future<String?> getSavedPrinterName() => impl.getSavedPrinterName();

  static Future<void> savePrinterName(String name) =>
      impl.savePrinterName(name);

  static Future<void> clearSavedPrinter() => impl.clearSavedPrinter();

  static Future<WindowsPrinterPaperInfo?> getPrinterPaperInfo({
    String? printerName,
  }) =>
      impl.getPrinterPaperInfo(printerName: printerName);

  static Future<void> printBytes(List<int> bytes, {String? printerName}) =>
      impl.printBytes(bytes, printerName: printerName);
}
