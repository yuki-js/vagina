import 'package:flutter/services.dart';

/// Minimal haptic feedback service.
///
/// This exists for backward compatibility with older code/tests that referenced
/// `HapticService` directly.
class HapticService {
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // In unit tests (no platform channels), this may fail. Swallow errors.
    }
  }

  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // In unit tests (no platform channels), this may fail. Swallow errors.
    }
  }
}
