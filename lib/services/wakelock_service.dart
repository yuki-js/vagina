import 'package:wakelock_plus/wakelock_plus.dart';
import 'log_service.dart';

/// Service for managing device wake lock to keep the screen on during calls
class WakeLockService {
  static const _tag = 'WakeLock';

  /// Enable wake lock to prevent device from sleeping
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      logService.info(_tag, 'Wake lock enabled');
    } catch (e) {
      logService.error(_tag, 'Failed to enable wake lock: $e');
    }
  }

  /// Disable wake lock to allow device to sleep normally
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      logService.info(_tag, 'Wake lock disabled');
    } catch (e) {
      logService.error(_tag, 'Failed to disable wake lock: $e');
    }
  }

  /// Check if wake lock is currently enabled
  Future<bool> isEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      logService.error(_tag, 'Failed to check wake lock status: $e');
      return false;
    }
  }
}
