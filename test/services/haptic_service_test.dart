import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/call_feedback_service.dart';

void main() {
  group('CallFeedbackService (Haptic)', () {
    late CallFeedbackService service;

    setUp(() {
      service = CallFeedbackService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('can be instantiated', () {
      expect(service, isNotNull);
    });

    testWidgets('heavyImpact can be called without throwing', (WidgetTester tester) async {
      // HapticFeedback requires a platform channel, so in tests it may fail silently
      // We just verify it doesn't throw an unhandled exception
      await expectLater(
        () async => await service.heavyImpact(),
        returnsNormally,
      );
    });

    testWidgets('selectionClick can be called without throwing', (WidgetTester tester) async {
      // HapticFeedback requires a platform channel, so in tests it may fail silently
      // We just verify it doesn't throw an unhandled exception
      await expectLater(
        () async => await service.selectionClick(),
        returnsNormally,
      );
    });
  });
}
