import 'package:flutter/material.dart';
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
      home: const HomeScreen(),
    );
  }
}
