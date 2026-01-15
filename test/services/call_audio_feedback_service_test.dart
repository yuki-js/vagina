import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/call_audio_feedback_service.dart';

void main() {
  group('CallAudioFeedbackService', () {
    late CallAudioFeedbackService service;

    setUp(() {
      service = CallAudioFeedbackService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should initialize without errors', () {
      expect(service, isNotNull);
    });

    test('should dispose without errors', () async {
      await expectLater(service.dispose(), completes);
    });

    test('should stop dial tone without errors even if not playing', () async {
      await expectLater(service.stopDialTone(), completes);
    });

    // Note: Cannot test actual audio playback in unit tests
    // These would require integration tests with platform channels
  });
}
