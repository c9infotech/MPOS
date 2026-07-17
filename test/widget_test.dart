import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mpos/app.dart';
import 'package:mpos/core/api/api_client.dart';
import 'package:mpos/core/api/pos_repository.dart';
import 'package:mpos/core/auth/auth_service.dart';
import 'package:mpos/core/config/app_config.dart';
import 'package:mpos/core/config/config_loader.dart';
import 'package:mpos/core/draft/pos_draft_service.dart';
import 'package:mpos/core/storage/pos_draft_store.dart';
import 'package:mpos/features/login/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MPOS splash navigates to login when logged out',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ConfigLoader.setForTesting(
      AppConfig(
        apiUrl: 'http://localhost/api/',
        companyDb: 'TEST_DB',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService(prefs);
    final app = MposApp(
      auth: auth,
      repository: PosRepository(ApiClient(), auth),
      posDrafts: PosDraftService(PosDraftStore(prefs)),
    );

    await tester.pumpWidget(app);
    expect(find.text('MPOS'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
