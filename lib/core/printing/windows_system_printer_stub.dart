bool get isSupported => false;

Future<List<String>> listPrinters() async => const [];

Future<String?> getDefaultPrinterName() async => null;

Future<String?> getSavedPrinterName() async => null;

Future<void> savePrinterName(String name) async {}

Future<void> clearSavedPrinter() async {}

Future<void> printBytes(List<int> bytes, {String? printerName}) async {
  throw UnsupportedError(
    'Windows system printer is not available on this platform.',
  );
}
