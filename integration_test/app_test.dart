import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vagina/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Initialization', () {
    testWidgets('App starts and shows OOBE or Home screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should show either OOBE or Home screen
      final oobeOrHomeFound = find.text('VAGINA').evaluate().isNotEmpty ||
          find.text('スピードダイヤル').evaluate().isNotEmpty;

      expect(oobeOrHomeFound, isTrue);
    });
  });

  group('Speed Dial', () {
    testWidgets('Default speed dial exists', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to speed dial tab if not already there
      final speedDialTabFinder = find.text('スピードダイヤル');
      if (speedDialTabFinder.evaluate().isNotEmpty) {
        await tester.tap(speedDialTabFinder);
        await tester.pumpAndSettle();
      }

      // Should see Default speed dial
      expect(find.text('Default'), findsWidgets);
    });
  });

  // Note: These are basic integration tests
  // More comprehensive tests would require mocking API calls
  // and setting up test data
}
