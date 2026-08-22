import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

import 'receipt_paper.dart';
import 'windows_printer_paper_info.dart';

const _nameKey = 'windows_system_printer_name';

bool get isSupported => Platform.isWindows;

Future<List<String>> listPrinters() async {
  if (!isSupported) return const [];
  return using((arena) {
    final pcbNeeded = arena<Uint32>();
    final pcReturned = arena<Uint32>();
    final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;

    EnumPrinters(flags, null, 4, null, 0, pcbNeeded, pcReturned);
    if (pcbNeeded.value == 0) return <String>[];

    final buffer = arena<Uint8>(pcbNeeded.value);
    final result = EnumPrinters(
      flags,
      null,
      4,
      buffer,
      pcbNeeded.value,
      pcbNeeded,
      pcReturned,
    );
    if (!result.value) {
      throw WindowsException(
        result.error.toHRESULT(),
        message: 'Could not list Windows printers.',
      );
    }

    final names = <String>[];
    final info = buffer.cast<PRINTER_INFO_4>();
    for (var i = 0; i < pcReturned.value; i++) {
      final name = info[i].pPrinterName.toDartString().trim();
      if (name.isNotEmpty) names.add(name);
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  });
}

Future<String?> getDefaultPrinterName() async {
  if (!isSupported) return null;
  return using((arena) {
    final size = arena<Uint32>()..value = 0;
    GetDefaultPrinter(null, size);
    if (size.value == 0) return null;

    final buffer = arena.pwstrBuffer(size.value);
    if (!GetDefaultPrinter(buffer, size)) return null;
    final name = buffer.toDartString().trim();
    return name.isEmpty ? null : name;
  });
}

Future<String?> getSavedPrinterName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_nameKey);
}

Future<void> savePrinterName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_nameKey, name);
}

Future<void> clearSavedPrinter() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_nameKey);
}

Future<String?> _resolvePrinterName(String? printerName) async {
  var target = printerName?.trim();
  if (target == null || target.isEmpty) {
    target = await getSavedPrinterName();
  }
  if (target == null || target.isEmpty) {
    target = await getDefaultPrinterName();
  }
  if (target == null || target.isEmpty) return null;
  return target;
}

/// Reads the configured paper width from Windows printer DEVMODE.
Future<WindowsPrinterPaperInfo?> getPrinterPaperInfo({String? printerName}) async {
  if (!isSupported) return null;

  final target = await _resolvePrinterName(printerName);
  if (target == null) return null;

  return using((arena) {
    final handlePtr = arena<Pointer<NativeType>>();
    final open = OpenPrinter(arena.pcwstr(target), handlePtr, null);
    if (!open.value) {
      return WindowsPrinterPaperInfo(
        paperSize: resolveWindowsPaperSize(printerName: target),
        printerName: target,
      );
    }

    final hPrinter = PRINTER_HANDLE(handlePtr.value);
    double? widthMm;
    try {
      final needed = arena<Uint32>();
      GetPrinter(hPrinter, 2, null, 0, needed);
      if (needed.value == 0) {
        return WindowsPrinterPaperInfo(
          paperSize: resolveWindowsPaperSize(printerName: target),
          printerName: target,
        );
      }

      final buffer = arena<Uint8>(needed.value);
      final result = GetPrinter(hPrinter, 2, buffer, needed.value, needed);
      if (!result.value) {
        return WindowsPrinterPaperInfo(
          paperSize: resolveWindowsPaperSize(printerName: target),
          printerName: target,
        );
      }

      final info = buffer.cast<PRINTER_INFO_2>();
      final devMode = info.ref.pDevMode;
      if (devMode != nullptr) {
        // DEVMODE paper width is stored in tenths of a millimeter.
        final tenthsMm = devMode.ref.dmPaperWidth;
        if (tenthsMm > 0) {
          widthMm = tenthsMm / 10.0;
        }
      }
    } finally {
      ClosePrinter(hPrinter);
    }

    return WindowsPrinterPaperInfo(
      paperSize: resolveWindowsPaperSize(
        printerName: target,
        devModeWidthMm: widthMm,
      ),
      widthMm: widthMm,
      printerName: target,
    );
  });
}

Future<void> printBytes(List<int> bytes, {String? printerName}) async {
  if (!isSupported) {
    throw UnsupportedError(
      'Windows system printer is not available on this platform.',
    );
  }
  if (bytes.isEmpty) {
    throw Exception('Nothing to print.');
  }

  var target = printerName?.trim();
  if (target == null || target.isEmpty) {
    target = await getSavedPrinterName();
  }
  if (target == null || target.isEmpty) {
    target = await getDefaultPrinterName();
  }
  if (target == null || target.isEmpty) {
    throw Exception(
      'No Windows printer selected. Open Printer settings and choose POS-58 (or your thermal printer).',
    );
  }

  final data = Uint8List.fromList(bytes);

  using((arena) {
    final handlePtr = arena<Pointer<NativeType>>();
    final open = OpenPrinter(arena.pcwstr(target!), handlePtr, null);
    if (!open.value) {
      throw WindowsException(
        open.error.toHRESULT(),
        message: 'Could not open printer "$target".',
      );
    }

    final hPrinter = PRINTER_HANDLE(handlePtr.value);
    try {
      final docInfo = arena<DOC_INFO_1>();
      docInfo.ref
        ..pDocName = arena.pwstr('MPOS Receipt')
        ..pDatatype = arena.pwstr('RAW')
        ..pOutputFile = PWSTR(nullptr);

      final jobId = StartDocPrinter(hPrinter, 1, docInfo);
      if (jobId == 0) {
        throw Exception('StartDocPrinter failed for "$target".');
      }

      try {
        if (!StartPagePrinter(hPrinter)) {
          throw Exception('StartPagePrinter failed for "$target".');
        }

        final buffer = data.toNative(allocator: arena);
        final written = arena<Uint32>();
        final ok = WritePrinter(hPrinter, buffer, data.length, written);
        if (!ok || written.value != data.length) {
          throw Exception('WritePrinter failed for "$target".');
        }

        EndPagePrinter(hPrinter);
      } finally {
        EndDocPrinter(hPrinter);
      }
    } finally {
      ClosePrinter(hPrinter);
    }
  });
}
