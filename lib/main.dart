import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vagina/api/native_oauth_protocol.dart';
import 'package:vagina/app.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/utils/platform_compat.dart';

/// Setup logging configuration based on build mode
void _setupLogging() {
  // Set log level based on build mode
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;

  // Configure console output
  Logger.root.onRecord.listen((record) {
    final time =
        '${record.time.hour.toString().padLeft(2, '0')}:'
        '${record.time.minute.toString().padLeft(2, '0')}:'
        '${record.time.second.toString().padLeft(2, '0')}.'
        '${(record.time.millisecond ~/ 100).toString()}';

    final level = record.level.name.padRight(7);
    final logger = record.loggerName.isEmpty ? 'ROOT' : record.loggerName;

    // Format: [HH:MM:SS.s] [LEVEL  ] [Logger] Message
    final message = '[$time] [$level] [$logger] ${record.message}';

    // Print to console
    // ignore: avoid_print
    print(message);

    // Print error and stack trace if present
    if (record.error != null) {
      // ignore: avoid_print
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  Stack trace:\n${record.stackTrace}');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  _setupLogging();

  // Initialize repositories and native callback registration before listening
  // for cold-start or warm OAuth callback activation.
  await AppContainer.initialize();
  await registerNativeOAuthProtocol();
  await AppContainer.authCallbacks.start();

  // Initialize window manager ONLY for desktop platforms
  // This prevents crashes on mobile (Android/iOS) and web
  if (PlatformCompat.isWindows ||
      PlatformCompat.isMacOS ||
      PlatformCompat.isLinux) {
    await windowManager.ensureInitialized();

    // Configure window options for desktop
    const windowOptions = WindowOptions(
      minimumSize: Size(400, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: App()));
}
