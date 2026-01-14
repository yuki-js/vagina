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
  /// Passes the SpeedDial directly via navigation parameters instead of
  /// going through the global store, following Flutter navigation best practices
  static Future<void> navigateToCallWithSpeedDial({
    required BuildContext context,
    required WidgetRef ref,
    required SpeedDial speedDial,
  }) async {
    // Set speed dial ID for session tracking
    final callService = ref.read(callServiceProvider);
    callService.setSpeedDialId(speedDial.id);

    // Navigate to call screen, passing SpeedDial configuration directly
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(speedDial: speedDial),
      ),
    );
    
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
