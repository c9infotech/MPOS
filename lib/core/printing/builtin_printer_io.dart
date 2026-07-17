import 'dart:io';

import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import 'builtin_printer_service.dart';

bool get isSupported => Platform.isAndroid;

Future<bool> isAvailable() async {
  if (!isSupported) return false;
  try {
    final info = await getInfo();
    return info.detected;
  } catch (_) {
    return false;
  }
}

Future<BuiltInPrinterInfo> getInfo() async {
  if (!isSupported) {
    return const BuiltInPrinterInfo();
  }
  try {
    return BuiltInPrinterInfo(
      status: await SunmiConfig.getStatus(),
      version: await SunmiConfig.getVersion(),
      paper: await SunmiConfig.getPaper(),
      type: await SunmiConfig.getType(),
      id: await SunmiConfig.getId(),
    );
  } catch (_) {
    return const BuiltInPrinterInfo();
  }
}

Future<void> printBytes(List<int> bytes) async {
  if (!isSupported) {
    throw UnsupportedError(
      'Built-in printer is only available on Android POS devices.',
    );
  }
  await SunmiPrinter.printEscPos(bytes);
}
