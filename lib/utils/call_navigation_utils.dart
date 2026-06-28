import 'package:flutter/material.dart';
import 'package:vagina/core/app/app_container.dart';
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
  /// use the user's persisted default character configuration.
  static Future<void> navigateToCallWithDefault({
    required BuildContext context,
  }) async {
    final speedDial = await AppContainer.speedDials.getById(SpeedDial.defaultId);
    if (speedDial == null) {
      throw StateError('Default speed dial not found.');
    }

    await navigateToCallWithSpeedDial(
      context: context,
      speedDial: speedDial,
    );
  }
}
