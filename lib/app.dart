import 'package:flutter/material.dart';

import 'core/api/pos_repository.dart';
import 'core/auth/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/login/login_screen.dart';
import 'features/main/main_shell.dart';
import 'features/splash/splash_screen.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.repository,
    required super.child,
  });

  final AuthService auth;
  final PosRepository repository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth || repository != oldWidget.repository;
}

class MposApp extends StatelessWidget {
  const MposApp({
    super.key,
    required this.auth,
    required this.repository,
  });

  final AuthService auth;
  final PosRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: auth,
      repository: repository,
      child: MaterialApp(
        title: 'MPOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
        routes: {
          LoginScreen.routeName: (_) => const LoginScreen(),
          MainShell.routeName: (_) => const MainShell(),
        },
      ),
    );
  }
}
