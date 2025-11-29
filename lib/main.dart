import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
      theme: AppTheme.darkTheme,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
