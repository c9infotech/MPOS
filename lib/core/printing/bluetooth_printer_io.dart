import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'bluetooth_printer_service.dart';

const _macKey = 'bt_printer_mac';
const _nameKey = 'bt_printer_name';

bool get isSupported =>
    Platform.isAndroid || Platform.isIOS || Platform.isWindows;

Future<String?> getSavedPrinterMac() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_macKey);
}

Future<String?> getSavedPrinterName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_nameKey);
}

Future<void> savePrinter({
  required String name,
  required String macAddress,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_macKey, macAddress);
  await prefs.setString(_nameKey, name);
}

Future<void> clearSavedPrinter() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_macKey);
  await prefs.remove(_nameKey);
}

Future<bool> ensurePermissions() async {
  if (!isSupported) return false;
  if (Platform.isAndroid) {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    final connect = statuses[Permission.bluetoothConnect];
    final scan = statuses[Permission.bluetoothScan];
    if (connect?.isGranted != true && scan?.isGranted != true) {
      // Older Android: plugin may still work with legacy BLUETOOTH permission.
      final granted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return granted;
    }
  }
  return PrintBluetoothThermal.isPermissionBluetoothGranted;
}

Future<bool> isBluetoothOn() async {
  if (!isSupported) return false;
  return PrintBluetoothThermal.bluetoothEnabled;
}

Future<List<PrinterDeviceInfo>> pairedDevices() async {
  if (!isSupported) return const [];
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return list
      .map(
        (d) => PrinterDeviceInfo(name: d.name, macAddress: d.macAdress),
      )
      .toList();
}

Future<bool> connect(String macAddress) async {
  if (!isSupported) return false;
  final already = await PrintBluetoothThermal.connectionStatus;
  if (already) return true;
  return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
}

Future<bool> isConnected() async {
  if (!isSupported) return false;
  return PrintBluetoothThermal.connectionStatus;
}

Future<void> disconnect() async {
  if (!isSupported) return;
  await PrintBluetoothThermal.disconnect;
}

Future<void> printBytes(List<int> bytes) async {
  if (!isSupported) {
    throw UnsupportedError('Bluetooth printing is not supported on this device');
  }
  final ok = await PrintBluetoothThermal.writeBytes(bytes);
  if (!ok) {
    throw Exception('Failed to send data to the printer');
  }
}
