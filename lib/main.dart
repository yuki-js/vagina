import 'utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home/home_screen.dart';
import 'screens/oobe/oobe_flow.dart';
import 'theme/app_theme.dart';
import 'repositories/repository_factory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
class VaginaApp extends StatefulWidget {
  const VaginaApp({super.key});

  @override
  State<VaginaApp> createState() => _VaginaAppState();
}

class _VaginaAppState extends State<VaginaApp> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // Use RepositoryFactory.preferences which shares the common KeyValueStore
    final isFirst = await RepositoryFactory.preferences.isFirstLaunch();

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
              ? const OOBEFlow()
              : const HomeScreen(),
    );
  }
}
