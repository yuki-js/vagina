import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speed_dial.dart';
import '../providers/providers.dart';
import '../screens/call/call_screen.dart';

/// Utility functions for initiating calls with SpeedDial configuration
/// These are navigation/UI helpers, not service methods
class CallNavigationUtils {
  /// Navigate to call screen with the specified SpeedDial configuration
  /// 
  /// This utility:
  /// 1. Saves the current assistant config
  /// 2. Applies the SpeedDial settings (name, system prompt, voice)
  /// 3. Sets the SpeedDial ID for session tracking
  /// 4. Navigates to the call screen
  /// 5. Restores the original config after the call ends
  static Future<void> navigateToCallWithSpeedDial({
    required BuildContext context,
    required WidgetRef ref,
    required SpeedDial speedDial,
  }) async {
    // Save current assistant config to restore after call
    final originalConfig = ref.read(assistantConfigProvider);
    
    // Update assistant config with speed dial settings
    ref.read(assistantConfigProvider.notifier).updateName(speedDial.name);
    ref.read(assistantConfigProvider.notifier).updateInstructions(speedDial.systemPrompt);
    ref.read(assistantConfigProvider.notifier).updateVoice(speedDial.voice);

    // Set speed dial ID for session tracking
    final callService = ref.read(callServiceProvider);
    callService.setSpeedDialId(speedDial.id);

    // Navigate to call screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CallScreen(),
      ),
    );
    
    // Restore original config after call ends
    ref.read(assistantConfigProvider.notifier).updateName(originalConfig.name);
    ref.read(assistantConfigProvider.notifier).updateInstructions(originalConfig.instructions);
    ref.read(assistantConfigProvider.notifier).updateVoice(originalConfig.voice);
    
    // Reset to default speed dial ID after call
    callService.setSpeedDialId(SpeedDial.defaultId);
  }

  /// Navigate to call screen with the Default SpeedDial
  /// 
  /// This is used by the FAB button and other entry points that should
  /// use the default character configuration
  static Future<void> navigateToCallWithDefault({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    await navigateToCallWithSpeedDial(
      context: context,
      ref: ref,
      speedDial: SpeedDial.defaultSpeedDial,
    );
  }
}
