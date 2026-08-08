import 'dart:io';

import 'printer_type.dart';

PrinterType get defaultType =>
    Platform.isWindows ? PrinterType.windows : PrinterType.bluetooth;

bool get isWindowsDesktop => Platform.isWindows;
