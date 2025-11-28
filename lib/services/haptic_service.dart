import 'package:flutter/services.dart';
import 'log_service.dart';

/// Service for providing haptic feedback to the user
/// 
/// This service encapsulates haptic feedback logic to provide
/// intuitive and accessible feedback for key events:
/// - Heavy impact: When AI response ends and user's turn begins
/// - Selection click: When VAD detects speech events
class HapticService {
  static const _tag = 'HapticService';

  /// Heavy impact haptic feedback
  /// 
  /// Used when AI's response turn ends and user's turn begins.
  /// This provides a strong, clear signal that the user can now speak.
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
      logService.debug(_tag, 'Heavy impact haptic triggered');
    } catch (e) {
      logService.warn(_tag, 'Failed to trigger heavy impact haptic: $e');
    }
  }

  /// Selection click haptic feedback
  /// 
  /// Used for VAD-related events:
  /// - When user speech is detected and recording begins
  /// - When user speech ends and AI audio starts
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
      logService.debug(_tag, 'Selection click haptic triggered');
    } catch (e) {
      logService.warn(_tag, 'Failed to trigger selection click haptic: $e');
    }
  }
}
