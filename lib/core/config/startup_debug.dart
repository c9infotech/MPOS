import 'dart:convert';
import 'dart:io';

/// Builds a copy-paste startup diagnostic report for support/debugging.
class StartupDebugReport {
  StartupDebugReport({
    required this.failedStep,
    required this.error,
    required this.stackTrace,
    this.configDiagnostics,
    this.prefsDiagnostics,
    this.recoveryNote,
  });

  final String failedStep;
  final Object error;
  final StackTrace stackTrace;
  final ConfigLoadDiagnostics? configDiagnostics;
  final PrefsLoadDiagnostics? prefsDiagnostics;
  final String? recoveryNote;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('=== MPOS STARTUP DEBUG ===')
      ..writeln('Time: ${DateTime.now().toIso8601String()}')
      ..writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('Failed step: $failedStep')
      ..writeln('Error type: ${error.runtimeType}')
      ..writeln('Error: $error')
      ..writeln();

    if (configDiagnostics != null) {
      buffer.writeln(configDiagnostics!.toReport());
      buffer.writeln();
    }

    if (prefsDiagnostics != null) {
      buffer.writeln(prefsDiagnostics!.toReport());
      buffer.writeln();
    }

    if (recoveryNote != null && recoveryNote!.isNotEmpty) {
      buffer.writeln('Recovery: $recoveryNote');
      buffer.writeln();
    }

    buffer
      ..writeln('--- Stack trace ---')
      ..writeln(stackTrace);

    return buffer.toString();
  }
}

/// Details about assets/config.json before jsonDecode.
class ConfigLoadDiagnostics {
  ConfigLoadDiagnostics({
    required this.assetPath,
    required this.rawLength,
    required this.firstBytesHex,
    required this.bomHint,
    required this.firstCharCode,
    required this.startsWithBrace,
    required this.preview,
  });

  final String assetPath;
  final int rawLength;
  final String firstBytesHex;
  final String bomHint;
  final int? firstCharCode;
  final bool startsWithBrace;
  final String preview;

  static ConfigLoadDiagnostics analyze(String assetPath, String raw) {
    final bytes = utf8.encode(raw);
    final hex = bytes
        .take(24)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');

    String bomHint = 'none detected (UTF-8 expected)';
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bomHint = 'UTF-16 LE BOM (FF FE) — save config.json as UTF-8';
    } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      bomHint = 'UTF-16 BE BOM (FE FF) — save config.json as UTF-8';
    } else if (bytes.isNotEmpty && bytes[0] == 0xEF && bytes.length >= 3) {
      bomHint = 'UTF-8 BOM (EF BB BF) — usually OK';
    } else if (bytes.isNotEmpty && bytes[0] == 0x00) {
      bomHint = 'starts with NULL byte — file may be binary/corrupted';
    }

    final preview = raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;

    return ConfigLoadDiagnostics(
      assetPath: assetPath,
      rawLength: raw.length,
      firstBytesHex: hex.isEmpty ? '(empty file)' : hex,
      bomHint: bomHint,
      firstCharCode: raw.isEmpty ? null : raw.codeUnitAt(0),
      startsWithBrace: raw.trimLeft().startsWith('{'),
      preview: preview.replaceAll('\r', '\\r').replaceAll('\n', '\\n'),
    );
  }

  String toReport() {
    return '''
--- config.json diagnostics ---
Asset path: $assetPath
Expected on disk (Windows Release):
  .\\data\\flutter_assets\\assets\\config.json
Raw text length: $rawLength chars
First char code: ${firstCharCode ?? 'n/a'} (123 = "{")
Starts with "{": $startsWithBrace
First bytes (hex): $firstBytesHex
Encoding hint: $bomHint
Content preview: $preview''';
  }
}

class PrefsLoadDiagnostics {
  PrefsLoadDiagnostics({
    required this.filePath,
    required this.exists,
    required this.rawLength,
    required this.firstBytesHex,
    required this.bomHint,
    required this.preview,
  });

  final String filePath;
  final bool exists;
  final int rawLength;
  final String firstBytesHex;
  final String bomHint;
  final String preview;

  static Future<PrefsLoadDiagnostics> read(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return PrefsLoadDiagnostics(
        filePath: '(unknown)',
        exists: false,
        rawLength: 0,
        firstBytesHex: '(path unavailable)',
        bomHint: 'Could not resolve preferences file path',
        preview: '(unavailable)',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return PrefsLoadDiagnostics(
        filePath: filePath,
        exists: false,
        rawLength: 0,
        firstBytesHex: '(file missing)',
        bomHint: 'shared_preferences.json not found yet',
        preview: '(unavailable)',
      );
    }

    final bytes = await file.readAsBytes();
    final hex = bytes
        .take(24)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');

    String bomHint = 'none detected (UTF-8 JSON expected)';
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bomHint = 'UTF-16 LE BOM — file is not valid JSON for SharedPreferences';
    } else if (bytes.isNotEmpty && bytes[0] == 0x00) {
      bomHint = 'starts with NULL byte — corrupted/binary preferences file';
    } else if (bytes.isNotEmpty && bytes[0] != 0x7B) {
      bomHint = 'does not start with "{" — corrupted preferences file';
    }

    String preview;
    try {
      final raw = utf8.decode(bytes, allowMalformed: true);
      preview = raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
      preview = preview.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    } catch (_) {
      preview = '(binary / unreadable text)';
    }

    return PrefsLoadDiagnostics(
      filePath: filePath,
      exists: true,
      rawLength: bytes.length,
      firstBytesHex: hex.isEmpty ? '(empty file)' : hex,
      bomHint: bomHint,
      preview: preview,
    );
  }

  String toReport() {
    return '''
--- shared_preferences diagnostics ---
File path: $filePath
Exists: $exists
Raw byte length: $rawLength
First bytes (hex): $firstBytesHex
Encoding hint: $bomHint
Content preview: $preview
Manual fix: close MPOS, delete this file, open MPOS again''';
  }
}

class StartupDebugException implements Exception {
  StartupDebugException(this.report);

  final StartupDebugReport report;

  @override
  String toString() => report.toString();
}
