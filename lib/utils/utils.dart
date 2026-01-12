/// Utils library - utility functions and classes
library;

export 'duration_formatter.dart';
export 'audio_utils.dart';
export 'url_utils.dart';
export 'platform_compat.dart';

import 'dart:convert';
import 'dart:math' as math;

/// General utility functions for common operations
class Utils {
  const Utils._();

  /// Generate a unique ID using timestamp and random suffix
  static String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(10000).toString().padLeft(4, '0');
    return '$timestamp-$random';
  }

  /// Safely parse JSON string, returns null on error
  static Map<String, dynamic>? tryParseJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Truncate string to max length with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Check if string is null or empty
  static bool isNullOrEmpty(String? value) {
    return value == null || value.isEmpty;
  }

  /// Check if string is null, empty, or contains only whitespace
  static bool isNullOrWhitespace(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// Safe division that returns 0 instead of throwing on division by zero
  static double safeDivide(num numerator, num denominator, {double defaultValue = 0.0}) {
    if (denominator == 0) return defaultValue;
    return numerator / denominator;
  }

  /// Clamp a value between min and max
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Convert bytes to human-readable format (KB, MB, GB)
  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    final value = bytes / math.pow(1024, i);
    return '${value.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Debounce a function call (delay execution until no calls for [duration])
  /// Returns a function that wraps the original function with debouncing
  static Function debounce(Function func, Duration duration) {
    DateTime? lastCall;
    return () {
      final now = DateTime.now();
      if (lastCall == null || now.difference(lastCall!) >= duration) {
        lastCall = now;
        func();
      }
    };
  }

  /// Deep copy a Map<String, dynamic> structure
  static Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
    final json = jsonEncode(source);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Deep copy a List<Map<String, dynamic>> structure
  static List<Map<String, dynamic>> deepCopyList(List<Map<String, dynamic>> source) {
    final json = jsonEncode(source);
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  /// Check if two lists have the same elements (order-independent)
  static bool listsEqual<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.difference(setB).isEmpty && setB.difference(setA).isEmpty;
  }

  /// Capitalize first letter of string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// Convert camelCase to snake_case
  static String camelToSnake(String text) {
    return text.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Convert snake_case to camelCase
  static String snakeToCamel(String text) {
    return text.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }

  /// Retry a future operation with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    var delay = initialDelay;
    
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        
        await Future.delayed(delay);
        delay *= backoffMultiplier;
      }
    }
    
    throw Exception('Retry failed after $maxAttempts attempts');
  }
}
