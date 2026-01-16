import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/haptic_service.dart';

void main() {
  group('HapticService', () {
    late HapticService hapticService;

    setUp(() {
      hapticService = HapticService();
    });

    test('can be instantiated', () {
      expect(hapticService, isNotNull);
    });

    testWidgets('heavyImpact can be called without throwing',
        (WidgetTester tester) async {
      // HapticFeedback requires a platform channel, so in tests it may fail silently
      // We just verify it doesn't throw an unhandled exception
      await expectLater(
        () async => await hapticService.heavyImpact(),
        returnsNormally,
      );
    });

    testWidgets('selectionClick can be called without throwing',
        (WidgetTester tester) async {
      // HapticFeedback requires a platform channel, so in tests it may fail silently
      // We just verify it doesn't throw an unhandled exception
      await expectLater(
        () async => await hapticService.selectionClick(),
        returnsNormally,
      );
    });
  });
}
