import 'printer_platform_stub.dart'
    if (dart.library.io) 'printer_platform_io.dart' as impl;
import 'printer_type.dart';

abstract final class PrinterPlatform {
  static PrinterType get defaultType => impl.defaultType;

  static bool get isWindowsDesktop => impl.isWindowsDesktop;
}