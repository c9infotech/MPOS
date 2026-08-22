import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class WindowsPrinterPaperInfo {
  const WindowsPrinterPaperInfo({
    required this.paperSize,
    this.widthMm,
    this.printerName,
  });

  final PaperSize paperSize;
  final double? widthMm;
  final String? printerName;
}
