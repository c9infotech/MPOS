/// How MPOS sends receipts to a printer.
enum PrinterType {
  /// External paired Bluetooth thermal printer.
  bluetooth,

  /// Built-in Android POS thermal printer (Sunmi / compatible).
  builtin,
}
