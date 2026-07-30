import 'package:package_info_plus/package_info_plus.dart';

/// Version shown on login (e.g. MPOS_1.2).
/// Set manually in pubspec.yaml: `version: 1.2.0+1`
Future<String> loadMposVersionLabel() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return mposVersionDisplayLabel(info.version);
  } catch (_) {
    return 'MPOS_1.0';
  }
}

String mposVersionDisplayLabel(String versionName) {
  final name = versionName.trim();
  if (name.isEmpty) return 'MPOS_1.0';
  if (name.startsWith('MPOS_')) return name;
  final parts = name.split('.');
  if (parts.length >= 2) {
    return 'MPOS_${parts[0]}.${parts[1]}';
  }
  return 'MPOS_$name';
}
