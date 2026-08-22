import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Maps a physical paper width (mm) to ESC/POS [PaperSize].
PaperSize paperSizeFromWidthMm(double widthMm) {
  if (widthMm <= 0) return PaperSize.mm58;
  if (widthMm <= 60) return PaperSize.mm58;
  if (widthMm <= 75) return PaperSize.mm72;
  return PaperSize.mm80;
}

/// Max characters per line (font A) for each paper size.
int maxCharsForPaper(PaperSize paper) {
  if (paper == PaperSize.mm58) return 32;
  if (paper == PaperSize.mm72) return 42;
  return 48;
}

/// Guess thermal width from printer name when Windows DEVMODE is missing/wrong.
double? guessWidthMmFromName(String printerName) {
  final name = printerName.toLowerCase();
  if (name.contains('58') || name.contains('pos-58') || name.contains('pos58')) {
    return 58;
  }
  if (name.contains('80') || name.contains('pos-80') || name.contains('pos80')) {
    return 80;
  }
  if (name.contains('72')) return 72;
  return null;
}

/// Resolve paper size for a Windows printer.
/// Printer name (e.g. POS-58) is preferred — USB thermal drivers often report wrong DEVMODE width.
PaperSize resolveWindowsPaperSize({
  required String printerName,
  double? devModeWidthMm,
}) {
  final guessed = guessWidthMmFromName(printerName);
  if (guessed != null) {
    return paperSizeFromWidthMm(guessed);
  }
  if (devModeWidthMm != null && devModeWidthMm >= 45 && devModeWidthMm <= 90) {
    return paperSizeFromWidthMm(devModeWidthMm);
  }
  return PaperSize.mm58;
}

/// ESC/POS: set print area width in dots (GS W xL xH).
List<int> escPosSetPrintWidth(PaperSize paper) {
  final w = paper.width;
  return [0x1D, 0x57, w & 0xFF, (w >> 8) & 0xFF];
}
