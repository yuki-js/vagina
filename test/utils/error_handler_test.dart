import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/utils/error_handler.dart';

void main() {
  group('AppError', () {
    test('NetworkError converts to user message', () {
      final error = NetworkError('Connection failed', code: 'timeout');
      expect(error.toUserMessage(), equals('接続がタイムアウトしました'));
    });

    test('AudioError converts to user message', () {
      final error = AudioError('Microphone error', code: 'permission_denied');
      expect(error.toUserMessage(), equals('マイクの使用を許可してください'));
    });

    test('ConfigurationError converts to user message', () {
      final error = ConfigurationError('Missing key', code: 'missing_api_key');
      expect(error.toUserMessage(), equals('Azure OpenAI設定を先に行ってください'));
    });

    test('ValidationError preserves message', () {
      final error = ValidationError('Invalid email format');
      expect(error.toUserMessage(), equals('Invalid email format'));
    });
  });

  group('ErrorHandler.handleAsync', () {
    test('successful operation returns result', () async {
      final result = await ErrorHandler.handleAsync(
        () async => 42,
        context: 'test',
      );
      expect(result, equals(42));
    });

    test('TimeoutException converts to NetworkError', () async {
      expect(
        () => ErrorHandler.handleAsync(
          () async {
            throw TimeoutException('Timeout');
          },
          context: 'test',
        ),
        throwsA(isA<NetworkError>().having(
          (e) => e.code,
          'code',
          'timeout',
        )),
      );
    });

    test('AppError is rethrown as-is', () async {
      final originalError = NetworkError('Test error');
      
      try {
        await ErrorHandler.handleAsync(
          () async {
            throw originalError;
          },
          context: 'test',
        );
        fail('Should have thrown');
      } catch (e) {
        expect(identical(e, originalError), isTrue);
      }
    });

    test('calls onError callback', () async {
      AppError? capturedError;

      try {
        await ErrorHandler.handleAsync(
          () async {
            throw Exception('Test');
          },
          context: 'test',
          onError: (error) {
            capturedError = error;
          },
        );
      } catch (_) {}

      expect(capturedError, isNotNull);
    });
  });

  group('ErrorHandler.handleSync', () {
    test('successful operation returns result', () {
      final result = ErrorHandler.handleSync(
        () => 'success',
        context: 'test',
      );
      expect(result, equals('success'));
    });

    test('generic exception converts to AppError', () {
      expect(
        () => ErrorHandler.handleSync(
          () => throw Exception('Test error'),
          context: 'test',
        ),
        throwsA(isA<AppError>()),
      );
    });

    test('FormatException converts to ValidationError', () {
      expect(
        () => ErrorHandler.handleSync(
          () => throw const FormatException('Invalid format'),
          context: 'test',
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('FileSystemException converts to StorageError', () {
      expect(
        () => ErrorHandler.handleSync(
          () => throw FileSystemException('Cannot read file'),
          context: 'test',
        ),
        throwsA(isA<StorageError>()),
      );
    });

    test('calls onError callback', () {
      AppError? capturedError;

      try {
        ErrorHandler.handleSync(
          () => throw Exception('Test'),
          context: 'test',
          onError: (error) {
            capturedError = error;
          },
        );
      } catch (_) {}

      expect(capturedError, isNotNull);
    });
  });

  group('ErrorHandler._categorizeError', () {
    test('categorizes socket errors as NetworkError', () {
      final error = SocketException('Connection refused');
      try {
        ErrorHandler.handleSync(
          () => throw error,
          context: 'test',
        );
      } catch (e) {
        expect(e, isA<NetworkError>());
      }
    });

    test('categorizes permission errors as AudioError', () {
      final error = Exception('Permission denied');
      try {
        ErrorHandler.handleSync(
          () => throw error,
          context: 'test',
        );
      } catch (e) {
        expect(e, isA<AudioError>());
        expect((e as AudioError).code, equals('permission_denied'));
      }
    });
  });

  group('ValidationError', () {
    test('supports field errors', () {
      final error = ValidationError(
        'Validation failed',
        fieldErrors: {
          'email': 'Invalid email format',
          'password': 'Too short',
        },
      );

      expect(error.fieldErrors, isNotNull);
      expect(error.fieldErrors!['email'], equals('Invalid email format'));
      expect(error.fieldErrors!['password'], equals('Too short'));
    });
  });
}
