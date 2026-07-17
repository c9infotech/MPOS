import 'package:shared_preferences/shared_preferences.dart';

import 'printer_type.dart';

abstract final class PrinterPrefs {
  static const _typeKey = 'printer_type';

  static Future<PrinterType> getType() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_typeKey);
    return PrinterType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => PrinterType.bluetooth,
    );
  }

  static Future<void> setType(PrinterType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, type.name);
  }
}
