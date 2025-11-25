import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina_screens/vagina_screens.dart';
import 'package:vagina_ui/vagina_ui.dart';

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
      home: const CallScreen(),
    );
  }
}
