import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/startup_debug.dart';

/// Loads SharedPreferences and auto-recovers from a corrupted JSON file on disk.
Future<SharedPreferences> loadSharedPreferencesSafely() async {
  try {
    return await SharedPreferences.getInstance();
  } on FormatException catch (error, stack) {
    final prefsPath = await sharedPreferencesFilePath();
    final diagnostics = await PrefsLoadDiagnostics.read(prefsPath);
    final deleted = await deleteSharedPreferencesFile(prefsPath);
    if (deleted) {
      try {
        return await SharedPreferences.getInstance();
      } catch (retryError, retryStack) {
        throw StartupDebugException(
          StartupDebugReport(
            failedStep: 'Initialize SharedPreferences (after reset)',
            error: retryError,
            stackTrace: retryStack,
            configDiagnostics: ConfigLoaderBridge.lastDiagnostics,
            prefsDiagnostics: diagnostics,
            recoveryNote:
                'Deleted corrupted shared_preferences.json but retry still failed.',
          ),
        );
      }
    }

    throw StartupDebugException(
      StartupDebugReport(
        failedStep: 'Initialize SharedPreferences',
        error: error,
        stackTrace: stack,
        configDiagnostics: ConfigLoaderBridge.lastDiagnostics,
        prefsDiagnostics: diagnostics,
        recoveryNote:
            'Could not delete preferences file automatically. Delete it manually and retry.',
      ),
    );
  }
}

Future<String?> sharedPreferencesFilePath() async {
  try {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}shared_preferences.json';
  } catch (_) {
    return null;
  }
}

Future<bool> deleteSharedPreferencesFile(String? filePath) async {
  if (filePath == null || filePath.isEmpty) return false;
  final file = File(filePath);
  if (!await file.exists()) return false;
  await file.delete();
  return true;
}

/// Avoid circular imports between config_loader and this file.
abstract final class ConfigLoaderBridge {
  static ConfigLoadDiagnostics? lastDiagnostics;
}
