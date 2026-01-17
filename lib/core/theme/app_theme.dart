import 'package:flutter/material.dart';
import 'dart:ui' as ui;

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

  /// Light theme colors
  static const Color lightBackgroundStart = Color(0xFFF5F7FA);
  static const Color lightBackgroundEnd = Color(0xFFE8EDF2);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  /// Get the light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'NotoSansJP',
      fontFamilyFallback: const ['NotoSansJP', 'Noto Sans JP', 'Noto Sans CJK JP', 'sans-serif'],
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        displaySmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        bodyMedium: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        bodySmall: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        labelMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        labelSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
      ).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightSurfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBackgroundStart,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
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
        fillColor: lightSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightTextSecondary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightTextSecondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: lightTextSecondary, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: lightTextSecondary, fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: lightTextSecondary.withValues(alpha: 0.2),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lightTextPrimary,
        ),
      ),
    );
  }

  /// Get the dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Explicitly specify sans-serif font to prevent Samsung devices from using Mincho (serif) font
      fontFamily: 'NotoSansJP',
      fontFamilyFallback: const ['NotoSansJP', 'Noto Sans JP', 'Noto Sans CJK JP', 'sans-serif'],
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        displaySmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontVariations: [ui.FontVariation('wght', 700)],
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        bodyMedium: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        bodySmall: const TextStyle(
          fontWeight: FontWeight.w500,
          fontVariations: [ui.FontVariation('wght', 500)],
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        labelMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
        labelSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontVariations: [ui.FontVariation('wght', 600)],
        ),
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
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
        labelStyle: const TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: surfaceColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
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

  /// Light background gradient decoration
  static BoxDecoration get lightBackgroundGradient {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lightBackgroundStart, lightBackgroundEnd],
      ),
    );
  }
}
