import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'bluetooth_printer_service.dart';
import 'builtin_printer_service.dart';
import 'printer_prefs.dart';
import 'printer_type.dart';
import 'receipt_builder.dart';
import 'receipt_data.dart';

Future<bool> printReceipt(
  BuildContext context,
  ReceiptData receipt,
) async {
  final type = await PrinterPrefs.getType();
  if (!context.mounted) return false;
  if (type == PrinterType.builtin) {
    return _printBuiltIn(context, receipt);
  }
  return _printBluetooth(context, receipt);
}

Future<bool> _printBuiltIn(
  BuildContext context,
  ReceiptData receipt,
) async {
  if (!BuiltInPrinterService.isSupported) {
    _toast(
      context,
      'Built-in printer works on Android POS devices only.',
      error: true,
    );
    return false;
  }

  final available = await BuiltInPrinterService.isAvailable();
  if (!available) {
    if (context.mounted) {
      _toast(
        context,
        'Built-in printer not found. Use Bluetooth mode or check device firmware.',
        error: true,
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  _showPrintingDialog(context);

  try {
    final bytes = await ReceiptBuilder.build(receipt);
    await BuiltInPrinterService.printBytes(bytes);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _toast(context, 'Receipt printed.');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _toast(context, e.toString(), error: true);
    }
    return false;
  }
}

Future<bool> _printBluetooth(
  BuildContext context,
  ReceiptData receipt,
) async {
  if (!BluetoothPrinterService.isSupported) {
    _toast(
      context,
      'Bluetooth printing works on Android/iOS devices only.',
      error: true,
    );
    return false;
  }

  final permitted = await BluetoothPrinterService.ensurePermissions();
  if (!permitted) {
    if (context.mounted) {
      _toast(context, 'Bluetooth permission is required.', error: true);
    }
    return false;
  }

  final btOn = await BluetoothPrinterService.isBluetoothOn();
  if (!btOn) {
    if (context.mounted) {
      _toast(context, 'Please turn on Bluetooth.', error: true);
    }
    return false;
  }

  var mac = await BluetoothPrinterService.getSavedPrinterMac();
  if (mac == null || mac.isEmpty) {
    if (!context.mounted) return false;
    mac = await _pickBluetoothPrinter(context);
    if (mac == null) return false;
  }

  if (!context.mounted) return false;
  _showPrintingDialog(context);

  try {
    final connected = await BluetoothPrinterService.connect(mac);
    if (!connected) {
      throw Exception(
        'Could not connect to printer. Open Printer settings and select it.',
      );
    }
    final bytes = await ReceiptBuilder.build(receipt);
    await BluetoothPrinterService.printBytes(bytes);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _toast(context, 'Receipt printed.');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _toast(context, e.toString(), error: true);
    }
    return false;
  }
}

Future<void> showPrintAfterSuccessDialog(
  BuildContext context, {
  required String message,
  required ReceiptData receipt,
}) async {
  if (!context.mounted) return;
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Success'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'done'),
          child: const Text('Done'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, 'print'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
          icon: const Icon(Icons.print),
          label: const Text('Print receipt'),
        ),
      ],
    ),
  );
  if (action == 'print' && context.mounted) {
    await printReceipt(context, receipt);
  }
}

Future<String?> _pickBluetoothPrinter(BuildContext context) async {
  final devices = await BluetoothPrinterService.pairedDevices();
  if (!context.mounted) return null;
  if (devices.isEmpty) {
    _toast(
      context,
      'No paired printers found. Pair your printer in phone Bluetooth settings, then try again.',
      error: true,
    );
    return null;
  }

  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Bluetooth printer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print, color: AppColors.emerald),
                title: Text(d.name.isEmpty ? 'Unknown' : d.name),
                subtitle: Text(d.macAddress),
                onTap: () async {
                  await BluetoothPrinterService.savePrinter(
                    name: d.name,
                    macAddress: d.macAddress,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, d.macAddress);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _showPrintingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.emerald),
              SizedBox(height: 16),
              Text('Printing…'),
            ],
          ),
        ),
      ),
    ),
  );
}

void _toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ),
  );
}
