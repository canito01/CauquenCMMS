import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sistema_maxi/core/services/app_providers.dart';
import 'package:sistema_maxi/core/services/local_storage_service.dart';
import 'package:sistema_maxi/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const SistemaMaxiApp(),
      ),
    );

    expect(find.byType(SistemaMaxiApp), findsOneWidget);
  });
}
