import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/pos_repository.dart';
import 'core/auth/auth_service.dart';
import 'core/config/config_loader.dart';
import 'core/draft/pos_draft_service.dart';
import 'core/storage/pos_draft_store.dart';
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
    await ConfigLoader.load();
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService(prefs);
    final repository = PosRepository(ApiClient(), auth);
    final posDrafts = PosDraftService(PosDraftStore(prefs));
    runApp(MposApp(
      auth: auth,
      repository: repository,
      posDrafts: posDrafts,
    ));
  } catch (error, stack) {
    debugPrint('MPOS startup failed: $error\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to start MPOS.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
