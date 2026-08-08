import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/printing/bluetooth_printer_service.dart';
import '../../core/printing/builtin_printer_service.dart';
import '../../core/printing/printer_platform.dart';
import '../../core/printing/printer_prefs.dart';
import '../../core/printing/printer_type.dart';
import '../../core/printing/receipt_builder.dart';
import '../../core/printing/receipt_data.dart';
import '../../core/printing/windows_system_printer_service.dart';
import '../../core/theme/app_colors.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  static const routeName = '/printer-settings';

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  PrinterType _type = PrinterType.bluetooth;
  bool _loading = true;
  bool _busy = false;

  // Bluetooth
  String? _savedBtName;
  String? _savedBtMac;
  List<PrinterDeviceInfo> _btDevices = [];
  String? _btStatus;

  // Windows system
  String? _savedWinName;
  String? _defaultWinName;
  List<String> _winPrinters = [];
  String? _winStatus;

  // Built-in
  BuiltInPrinterInfo? _builtInInfo;
  bool _builtInAvailable = false;
  String? _builtInStatus;

  bool get _isWindows => PrinterPlatform.isWindowsDesktop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _type = await PrinterPrefs.getType();
    // Migrate invalid type for this platform.
    if (_isWindows && _type == PrinterType.builtin) {
      _type = PrinterType.windows;
      await PrinterPrefs.setType(_type);
    } else if (!_isWindows && _type == PrinterType.windows) {
      _type = PrinterType.bluetooth;
      await PrinterPrefs.setType(_type);
    }
    await _refreshCurrentMode();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshCurrentMode() async {
    if (_type == PrinterType.bluetooth) {
      await _refreshBluetooth();
    } else if (_type == PrinterType.windows) {
      await _refreshWindows();
    } else {
      await _refreshBuiltIn();
    }
  }

  Future<void> _refreshBluetooth() async {
    _btStatus = null;
    if (!BluetoothPrinterService.isSupported) {
      _btStatus =
          'Bluetooth printing is not available on this platform.';
      return;
    }

    final permitted = await BluetoothPrinterService.ensurePermissions();
    if (!permitted) {
      _btStatus = 'Bluetooth permission denied.';
      return;
    }

    final btOn = await BluetoothPrinterService.isBluetoothOn();
    if (!btOn) {
      _btStatus = 'Bluetooth is off. Turn it on and refresh.';
      return;
    }

    _savedBtName = await BluetoothPrinterService.getSavedPrinterName();
    _savedBtMac = await BluetoothPrinterService.getSavedPrinterMac();
    _btDevices = await BluetoothPrinterService.pairedDevices();
    if (_btDevices.isEmpty) {
      _btStatus = _isWindows
          ? 'No Bluetooth printers found. For USB POS-58, switch to Windows printer mode.'
          : 'No paired devices. Pair your thermal printer in Bluetooth settings, then tap Refresh.';
    }
  }

  Future<void> _refreshWindows() async {
    _winStatus = null;
    if (!WindowsSystemPrinterService.isSupported) {
      _winStatus = 'Windows printer mode is only available on Windows desktop.';
      return;
    }

    _savedWinName = await WindowsSystemPrinterService.getSavedPrinterName();
    _defaultWinName = await WindowsSystemPrinterService.getDefaultPrinterName();
    _winPrinters = await WindowsSystemPrinterService.listPrinters();

    if (_winPrinters.isEmpty) {
      _winStatus =
          'No printers found. Install POS-58 in Windows Settings → Printers & scanners, then Refresh.';
      return;
    }

    if ((_savedWinName == null || _savedWinName!.isEmpty) &&
        _defaultWinName != null &&
        _defaultWinName!.isNotEmpty) {
      // Prefer default when nothing saved yet (e.g. POS-58 set as default).
      _savedWinName = _defaultWinName;
      await WindowsSystemPrinterService.savePrinterName(_defaultWinName!);
    }
  }

  Future<void> _refreshBuiltIn() async {
    _builtInStatus = null;
    _builtInInfo = null;
    _builtInAvailable = false;

    if (!BuiltInPrinterService.isSupported) {
      _builtInStatus =
          'Built-in printer is only available on Android POS terminals.';
      return;
    }

    _builtInInfo = await BuiltInPrinterService.getInfo();
    _builtInAvailable = await BuiltInPrinterService.isAvailable();
    if (!_builtInAvailable) {
      _builtInStatus =
          'Built-in printer service not detected. This works on Sunmi and compatible Android POS devices with an internal printer.';
    }
  }

  Future<void> _setType(PrinterType type) async {
    await PrinterPrefs.setType(type);
    if (!mounted) return;
    setState(() {
      _type = type;
      _loading = true;
    });
    await _refreshCurrentMode();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectBluetooth(PrinterDeviceInfo device) async {
    setState(() => _busy = true);
    try {
      final ok = await BluetoothPrinterService.connect(device.macAddress);
      if (!ok) throw Exception('Connection failed');
      await BluetoothPrinterService.savePrinter(
        name: device.name,
        macAddress: device.macAddress,
      );
      if (!mounted) return;
      setState(() {
        _savedBtName = device.name;
        _savedBtMac = device.macAddress;
      });
      _snack('Saved printer: ${device.name}');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not connect: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectWindows(String name) async {
    setState(() => _busy = true);
    try {
      await WindowsSystemPrinterService.savePrinterName(name);
      if (!mounted) return;
      setState(() => _savedWinName = name);
      _snack('Saved printer: $name');
    } catch (e) {
      if (!mounted) return;
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearBluetooth() async {
    await BluetoothPrinterService.clearSavedPrinter();
    await BluetoothPrinterService.disconnect();
    if (!mounted) return;
    setState(() {
      _savedBtName = null;
      _savedBtMac = null;
    });
  }

  Future<void> _clearWindows() async {
    await WindowsSystemPrinterService.clearSavedPrinter();
    if (!mounted) return;
    setState(() => _savedWinName = null);
  }

  Future<void> _testPrint() async {
    setState(() => _busy = true);
    try {
      final receipt = const ReceiptData(
        title: 'Test Print',
        currency: 'USD',
        lines: [
          ReceiptLine(
            code: 'TEST',
            name: 'MPOS printer test',
            qty: 1,
            price: 0,
          ),
        ],
        subtotal: 0,
        tax: 0,
        total: 0,
        footer: 'Printer OK',
      );
      final bytes = await ReceiptBuilder.build(receipt);

      if (_type == PrinterType.builtin) {
        if (!_builtInAvailable) {
          throw Exception('Built-in printer not available on this device');
        }
        await BuiltInPrinterService.printBytes(bytes);
      } else if (_type == PrinterType.windows) {
        final name = _savedWinName;
        if (name == null || name.isEmpty) {
          throw Exception('Select a Windows printer first');
        }
        await WindowsSystemPrinterService.printBytes(bytes, printerName: name);
      } else {
        if (_savedBtMac == null || _savedBtMac!.isEmpty) {
          throw Exception('Select a Bluetooth printer first');
        }
        final ok = await BluetoothPrinterService.connect(_savedBtMac!);
        if (!ok) throw Exception('Not connected');
        await BluetoothPrinterService.printBytes(bytes);
      }

      if (!mounted) return;
      _snack('Test print sent');
    } catch (e) {
      if (!mounted) return;
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  List<ButtonSegment<PrinterType>> get _segments {
    if (_isWindows) {
      return const [
        ButtonSegment(
          value: PrinterType.windows,
          label: Text('Windows'),
          icon: Icon(Icons.print),
        ),
        ButtonSegment(
          value: PrinterType.bluetooth,
          label: Text('Bluetooth'),
          icon: Icon(Icons.bluetooth),
        ),
      ];
    }
    return const [
      ButtonSegment(
        value: PrinterType.bluetooth,
        label: Text('Bluetooth'),
        icon: Icon(Icons.bluetooth),
      ),
      ButtonSegment(
        value: PrinterType.builtin,
        label: Text('Built-in POS'),
        icon: Icon(Icons.point_of_sale),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.textOnPrimary,
        title: const Text('Printer Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _busy
                ? null
                : () async {
                    setState(() => _loading = true);
                    await _refreshCurrentMode();
                    if (mounted) setState(() => _loading = false);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kIsWeb)
                  const _InfoBanner(
                    text:
                        'Printing requires the Android app on a phone or POS terminal.',
                  ),
                const Text(
                  'Printer type',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PrinterType>(
                  segments: _segments,
                  selected: {_type},
                  onSelectionChanged: (value) {
                    if (value.isNotEmpty) _setType(value.first);
                  },
                ),
                const SizedBox(height: 16),
                if (_type == PrinterType.bluetooth) _buildBluetoothSection(),
                if (_type == PrinterType.windows) _buildWindowsSection(),
                if (_type == PrinterType.builtin) _buildBuiltInSection(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _testPrint,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long),
                  label: const Text('Test print'),
                ),
              ],
            ),
    );
  }

  Widget _buildWindowsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_winStatus != null) ...[
          _InfoBanner(text: _winStatus!),
          const SizedBox(height: 12),
        ],
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: const Icon(Icons.print, color: AppColors.emerald),
            title: Text(
              _savedWinName?.isNotEmpty == true
                  ? _savedWinName!
                  : 'No printer selected',
            ),
            subtitle: Text(
              _defaultWinName != null && _defaultWinName!.isNotEmpty
                  ? 'Windows default: $_defaultWinName'
                  : 'Select an installed printer below (e.g. POS-58)',
            ),
            trailing: _savedWinName != null
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: _clearWindows,
                    icon: const Icon(Icons.link_off),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Uses RAW ESC/POS to the Windows printer driver. Use this for USB thermal printers like POS-58 (not Chrome print dialog).',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text(
          'Installed printers',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_winPrinters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No printers listed.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ..._winPrinters.map(
            (name) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(name),
                subtitle: name == _defaultWinName
                    ? const Text('Windows default')
                    : null,
                trailing: _savedWinName == name
                    ? const Icon(Icons.check_circle, color: AppColors.emerald)
                    : const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _selectWindows(name),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBluetoothSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_btStatus != null) ...[
          _InfoBanner(text: _btStatus!),
          const SizedBox(height: 12),
        ],
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: const Icon(Icons.bluetooth, color: AppColors.emerald),
            title: Text(
              _savedBtName?.isNotEmpty == true
                  ? _savedBtName!
                  : 'No printer selected',
            ),
            subtitle: Text(_savedBtMac ?? 'Pair and select a device below'),
            trailing: _savedBtMac != null
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: _clearBluetooth,
                    icon: const Icon(Icons.link_off),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Paired devices',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_btDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No devices listed.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ..._btDevices.map(
            (d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(d.name.isEmpty ? 'Unknown' : d.name),
                subtitle: Text(d.macAddress),
                trailing: _savedBtMac == d.macAddress
                    ? const Icon(Icons.check_circle, color: AppColors.emerald)
                    : const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _selectBluetooth(d),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBuiltInSection() {
    final info = _builtInInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_builtInStatus != null) ...[
          _InfoBanner(text: _builtInStatus!),
          const SizedBox(height: 12),
        ],
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _builtInAvailable
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: _builtInAvailable
                          ? AppColors.emerald
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _builtInAvailable
                            ? 'Built-in printer ready'
                            : 'Built-in printer not detected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (info != null && info.detected) ...[
                  const SizedBox(height: 12),
                  if (info.status?.isNotEmpty == true)
                    _infoRow('Status', info.status!),
                  if (info.type?.isNotEmpty == true)
                    _infoRow('Type', info.type!),
                  if (info.paper?.isNotEmpty == true)
                    _infoRow('Paper', info.paper!),
                  if (info.version?.isNotEmpty == true)
                    _infoRow('Version', info.version!),
                  if (info.id?.isNotEmpty == true) _infoRow('ID', info.id!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use this mode on Android POS handhelds with an internal thermal printer (Sunmi and compatible devices). No Bluetooth pairing is required.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textPrimary)),
    );
  }
}
