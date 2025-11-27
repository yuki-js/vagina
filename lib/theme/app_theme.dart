import 'package:flutter/material.dart';

/// App theme configuration
class AppTheme {
  const AppTheme._();

  /// Primary color - Deep purple for a modern feel
  static const Color primaryColor = Color(0xFF6C63FF);

  /// Secondary color - Teal accent
  static const Color secondaryColor = Color(0xFF00D9FF);

  /// Background color - Dark gradient start
  static const Color backgroundStart = Color(0xFF1A1A2E);

  /// Background color - Dark gradient end
  static const Color backgroundEnd = Color(0xFF16213E);

  /// Surface color for cards and elevated elements
  static const Color surfaceColor = Color(0xFF2A2A4A);

  /// Error color - Red
  static const Color errorColor = Color(0xFFFF6B6B);

  /// Success color - Green
  static const Color successColor = Color(0xFF4ECB71);

  /// Warning color - Yellow
  static const Color warningColor = Color(0xFFFFE66D);

  /// Text color - Primary
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Text color - Secondary
  static const Color textSecondary = Color(0xFFB8B8D1);

  /// Get the dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundStart,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: surfaceColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
        ),
      ),
    );
  }

  /// Background gradient decoration
  static BoxDecoration get backgroundGradient {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundStart, backgroundEnd],
      ),
    );
  }
}
