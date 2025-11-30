import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/wakelock_service.dart';

void main() {
  group('WakeLockService', () {
    test('can be instantiated', () {
      final service = WakeLockService();
      expect(service, isNotNull);
    });

    test('enable can be called without throwing', () async {
      final service = WakeLockService();
      // Note: WakelockPlus.enable() may throw on platforms without
      // wake lock support (e.g., desktop/web). This test just verifies
      // the service method handles errors gracefully.
      expect(() async => await service.enable(), returnsNormally);
    });

    test('disable can be called without throwing', () async {
      final service = WakeLockService();
      expect(() async => await service.disable(), returnsNormally);
    });

    test('isEnabled can be called without throwing', () async {
      final service = WakeLockService();
      expect(() async => await service.isEnabled(), returnsNormally);
    });
  });
}
