import 'utils/platform_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';
import 'core/state/repository_providers.dart';
import 'feat/home/screens/home.dart';
import 'feat/oobe/screens/oobe_flow.dart';
import 'core/theme/app_theme.dart';
import 'repositories/repository_factory.dart';

/// Setup logging configuration based on build mode
void _setupLogging() {
  // Set log level based on build mode
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;

  // Configure console output
  Logger.root.onRecord.listen((record) {
    final time = '${record.time.hour.toString().padLeft(2, '0')}:'
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

  // Initialize repositories
  await RepositoryFactory.initialize();

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

  runApp(
    const ProviderScope(
      child: VaginaApp(),
    ),
  );
}

/// Main application widget
class VaginaApp extends ConsumerStatefulWidget {
  const VaginaApp({super.key});

  @override
  ConsumerState<VaginaApp> createState() => _VaginaAppState();
}

class _VaginaAppState extends ConsumerState<VaginaApp> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // Use preferencesRepositoryProvider instead of RepositoryFactory
    final preferences = ref.read(preferencesRepositoryProvider);
    final isFirst = await preferences.isFirstLaunch();

    if (mounted) {
      setState(() {
        _isFirstLaunch = isFirst;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAGINA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Default to light theme for home screen
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _isFirstLaunch
              ? const OobeFlowScreen()
              : const HomeScreen(),
    );
  }
}
