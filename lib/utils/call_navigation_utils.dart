import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/screens/call.dart';
import 'package:vagina/models/speed_dial.dart';

/// Utility functions for initiating calls with SpeedDial configuration
/// These are navigation/UI helpers, not service methods
class CallNavigationUtils {
  /// Navigate to call screen with the specified SpeedDial configuration
  ///
  /// Passes the SpeedDial directly via navigation parameters.
  /// Note: CallService initialization is deferred to inside CallScreen scope
  /// to ensure proper CallScoped provider isolation.
  static Future<void> navigateToCallWithSpeedDial({
    required BuildContext context,
    required SpeedDial speedDial,
  }) async {
    // Navigate to call screen, passing SpeedDial configuration directly
    // CallScreen will handle all call initialization within its ProviderScope
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(speedDial: speedDial),
      ),
    );
  }

  /// Navigate to call screen with the Default SpeedDial
  ///
  /// This is used by the FAB button and other entry points that should
  /// use the default character configuration
  static Future<void> navigateToCallWithDefault({
    required BuildContext context,
  }) async {
    await navigateToCallWithSpeedDial(
      context: context,
      speedDial: SpeedDial.defaultSpeedDial,
    );
  }
}
