import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/pos_repository.dart';
import 'core/auth/auth_service.dart';
import 'core/config/config_loader.dart';
import 'core/config/startup_debug.dart';
import 'core/draft/pos_draft_service.dart';
import 'core/storage/safe_shared_preferences.dart';
import 'core/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.appBar,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await _runStartupStep('Load config.json', ConfigLoader.load);
    final prefs = await _runStartupStep(
      'Initialize SharedPreferences',
      loadSharedPreferencesSafely,
    );
    final auth = AuthService(prefs);
    final repository = PosRepository(ApiClient(), auth);
    final posDrafts = PosDraftService(repository);
    runApp(MposApp(
      auth: auth,
      repository: repository,
      posDrafts: posDrafts,
    ));
  } catch (error, stack) {
    final report = error is StartupDebugException
        ? error.report
        : StartupDebugReport(
            failedStep: 'Unknown startup step',
            error: error,
            stackTrace: stack,
          );
    debugPrint(report.toString());
    runApp(_StartupErrorApp(report: report));
  }
}

Future<T> _runStartupStep<T>(
  String step,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } catch (e, st) {
    if (e is StartupDebugException) rethrow;
    throw StartupDebugException(
      StartupDebugReport(
        failedStep: step,
        error: e,
        stackTrace: st,
        configDiagnostics: ConfigLoader.lastDiagnostics,
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.report});

  final StartupDebugReport report;

  @override
  Widget build(BuildContext context) {
    final text = report.toString();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MPOS startup failed'),
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Copy the debug report below and send it for support.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug report copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy debug report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
