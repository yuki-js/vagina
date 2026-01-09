import 'utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home/new_home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager ONLY for desktop platforms
  // This prevents crashes on mobile (Android/iOS) and web
  if (PlatformCompat.isWindows || PlatformCompat.isMacOS || PlatformCompat.isLinux) {
    await windowManager.ensureInitialized();
    
    // Configure window options for desktop
    const windowOptions = WindowOptions(
      minimumSize: Size(400, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Hide native title bar for custom immersive UI
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
class VaginaApp extends StatelessWidget {
  const VaginaApp({super.key});

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
      home: const NewHomeScreen(),
    );
  }
}
