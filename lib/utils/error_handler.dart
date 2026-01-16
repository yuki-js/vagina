/// Standardized error handling for the application
///
/// This module provides consistent error types, handling patterns,
/// and utilities for error management across the codebase.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Base class for all application errors
abstract class AppError implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppError(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(runtimeType);
    if (code != null) buffer.write(' [$code]');
    buffer.write(': $message');
    if (originalError != null && kDebugMode) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }

  /// Convert to a user-friendly message (Japanese)
  String toUserMessage() => message;
}

/// Error related to network/API operations
class NetworkError extends AppError {
  const NetworkError(
    String message, {
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toUserMessage() {
    if (code == 'timeout') return '接続がタイムアウトしました';
    if (code == 'no_connection') return 'ネットワークに接続できません';
    return '通信エラーが発生しました: $message';
  }
}

/// Error related to audio operations
class AudioError extends AppError {
  const AudioError(
    String message, {
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toUserMessage() {
    if (code == 'permission_denied') return 'マイクの使用を許可してください';
    if (code == 'device_not_found') return 'オーディオデバイスが見つかりません';
    return '音声エラー: $message';
  }
}

/// Error related to storage/persistence
class StorageError extends AppError {
  const StorageError(
    String message, {
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toUserMessage() {
    if (code == 'permission_denied') return 'ストレージへのアクセス権限がありません';
    if (code == 'not_found') return 'データが見つかりません';
    return 'ストレージエラー: $message';
  }
}

/// Error related to configuration
class ConfigurationError extends AppError {
  const ConfigurationError(
    String message, {
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toUserMessage() {
    if (code == 'missing_api_key') return 'Azure OpenAI設定を先に行ってください';
    if (code == 'invalid_config') return '設定が正しくありません';
    return '設定エラー: $message';
  }
}

/// Error related to validation
class ValidationError extends AppError {
  final Map<String, String>? fieldErrors;

  const ValidationError(
    String message, {
    String? code,
    this.fieldErrors,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toUserMessage() => message;
}

/// Utility class for standardized error handling
class ErrorHandler {
  const ErrorHandler._();

  /// Wrap an operation with error handling
  ///
  /// Converts exceptions into AppErrors and optionally logs them
  static Future<T> handleAsync<T>(
    Future<T> Function() operation, {
    required String context,
    void Function(AppError)? onError,
  }) async {
    try {
      return await operation();
    } on AppError {
      rethrow; // Already an AppError, just rethrow
    } on TimeoutException catch (e, stack) {
      final error = NetworkError(
        'Operation timed out in $context',
        code: 'timeout',
        originalError: e,
        stackTrace: stack,
      );
      onError?.call(error);
      throw error;
    } catch (e, stack) {
      final error = _categorizeError(e, stack, context);
      onError?.call(error);
      throw error;
    }
  }

  /// Wrap a synchronous operation with error handling
  static T handleSync<T>(
    T Function() operation, {
    required String context,
    void Function(AppError)? onError,
  }) {
    try {
      return operation();
    } on AppError {
      rethrow;
    } catch (e, stack) {
      final error = _categorizeError(e, stack, context);
      onError?.call(error);
      throw error;
    }
  }

  /// Categorize a generic error into specific AppError types
  static AppError _categorizeError(
      Object error, StackTrace stack, String context) {
    final message = error.toString();

    // Network-related errors
    if (message.contains('SocketException') ||
        message.contains('HttpException') ||
        message.contains('WebSocket')) {
      return NetworkError(
        'Network error in $context',
        originalError: error,
        stackTrace: stack,
      );
    }

    // Permission errors
    if (message.contains('permission') || message.contains('Permission')) {
      return AudioError(
        'Permission denied in $context',
        code: 'permission_denied',
        originalError: error,
        stackTrace: stack,
      );
    }

    // Storage errors
    if (message.contains('FileSystemException') ||
        message.contains('PathAccessException')) {
      return StorageError(
        'Storage error in $context',
        originalError: error,
        stackTrace: stack,
      );
    }

    // Validation errors
    if (message.contains('FormatException') || message.contains('format')) {
      return ValidationError(
        'Invalid format in $context',
        originalError: error,
        stackTrace: stack,
      );
    }

    // Generic error
    return _GenericError(
      'Unexpected error in $context: $message',
      originalError: error,
      stackTrace: stack,
    );
  }

  /// Create an error stream controller with consistent error handling
  static StreamController<T> createErrorHandlingController<T>({
    bool broadcast = true,
    void Function(Object, StackTrace)? onError,
  }) {
    return StreamController<T>.broadcast(
      onListen: null,
      onCancel: null,
      sync: false,
    );
  }
}

/// Generic application error (internal use)
class _GenericError extends AppError {
  const _GenericError(
    String message, {
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
