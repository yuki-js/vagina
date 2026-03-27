import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

const _defaultKeyPath = '/tmp/aoai_key.txt';
const _defaultUrl =
    'https://oas-playground-swe.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-realtime';
const _defaultPrompt = 'Reply with exactly: AOAI probe success.';
const _defaultInstructions =
    'You are a connectivity probe. Reply to the next user message with exactly the requested text and nothing else.';
const _defaultTimeoutSeconds = 45;

Future<void> main(List<String> args) async {
  final options = _ProbeOptions.parse(args);

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final keyFile = File(options.keyPath);
  if (!await keyFile.exists()) {
    stderr.writeln('Key file not found: ${options.keyPath}');
    exitCode = 2;
    return;
  }

  final apiKey = (await keyFile.readAsString()).trim();
  if (apiKey.isEmpty) {
    stderr.writeln('Key file is empty: ${options.keyPath}');
    exitCode = 2;
    return;
  }

  final baseUri = Uri.parse(options.url);
  final targetUri = _normalizeWebSocketUri(baseUri).replace(
    queryParameters: {
      ...baseUri.queryParameters,
      'api-key': apiKey,
    },
  );

  final done = Completer<void>();
  final streamedText = StringBuffer();
  StreamSubscription<dynamic>? subscription;
  Timer? fallbackPromptTimer;
  String? finalText;
  bool sessionUpdateSent = false;
  bool promptSent = false;

  void logRecvType(Map<String, dynamic> message) {
    stdout.writeln('RECV ${message['type'] ?? 'unknown'}');
    stdout.writeln(_prettyJson(_redactJsonValue(message)));
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!done.isCompleted) {
      done.completeError(error, stackTrace ?? StackTrace.current);
    }
  }

  void sendJson(IOWebSocketChannel channel, Map<String, dynamic> payload) {
    stdout.writeln('SEND ${payload['type'] ?? 'unknown'}');
    stdout.writeln(_prettyJson(_redactJsonValue(payload)));
    channel.sink.add(jsonEncode(payload));
  }

  Future<void> sendPrompt(IOWebSocketChannel channel) async {
    if (promptSent) {
      return;
    }
    promptSent = true;
    sendJson(channel, {
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': options.prompt,
          },
        ],
      },
    });
    sendJson(channel, {
      'type': 'response.create',
      'response': {
        'modalities': ['text'],
      },
    });
  }

  try {
    stdout.writeln('Connecting to Azure OpenAI Realtime probe target...');
    stdout.writeln('URL: ${_redactSensitiveParams(targetUri.toString())}');
    stdout.writeln('Key path: ${options.keyPath}');

    final channel = IOWebSocketChannel.connect(targetUri);
    await channel.ready.timeout(Duration(seconds: options.timeoutSeconds));
    stdout.writeln('STATE connected');

    subscription = channel.stream.listen(
      (data) async {
        try {
          final decoded = data is String ? jsonDecode(data) : data;
          if (decoded is! Map) {
            stderr.writeln('Ignoring non-object message');
            return;
          }

          final message = Map<String, dynamic>.from(decoded);
          final type = message['type'] as String? ?? 'unknown';
          logRecvType(message);

          switch (type) {
            case 'session.created':
              stdout.writeln(
                'EVENT session.created id=${((message['session'] as Map?)?['id'] ?? '')}',
              );
              if (!sessionUpdateSent) {
                sessionUpdateSent = true;
                sendJson(channel, {
                  'type': 'session.update',
                  'session': {
                    'modalities': ['text'],
                    'instructions': options.instructions,
                  },
                });
                fallbackPromptTimer?.cancel();
                fallbackPromptTimer = Timer(const Duration(seconds: 2), () async {
                  try {
                    await sendPrompt(channel);
                  } catch (error, stackTrace) {
                    completeError(error, stackTrace);
                  }
                });
              }
              break;
            case 'session.updated':
              stdout.writeln(
                'EVENT session.updated model=${((message['session'] as Map?)?['model'] ?? '')}',
              );
              fallbackPromptTimer?.cancel();
              await sendPrompt(channel);
              break;
            case 'response.created':
              final response = message['response'];
              if (response is Map) {
                stdout.writeln(
                  'EVENT response.created id=${response['id'] ?? ''} status=${response['status'] ?? ''}',
                );
              }
              break;
            case 'response.text.delta':
            case 'response.output_text.delta':
              final delta = message['delta'] as String?;
              if (delta != null && delta.isNotEmpty) {
                streamedText.write(delta);
                stdout.write(delta);
              }
              break;
            case 'response.text.done':
            case 'response.output_text.done':
              final text = message['text'] as String?;
              if (text != null && text.isNotEmpty) {
                finalText = text;
                stdout.writeln('\nEVENT $type text="$text"');
              }
              break;
            case 'response.done':
              final response = message['response'];
              final status = response is Map ? response['status'] ?? '' : '';
              stdout.writeln('\nEVENT response.done status=$status');
              if (!done.isCompleted) {
                done.complete();
              }
              break;
            case 'error':
              final error = message['error'];
              String errorMessage = 'Unknown server error';
              if (error is Map) {
                final typePart = error['type']?.toString() ?? 'error';
                final codePart = error['code']?.toString() ?? '';
                final messagePart = error['message']?.toString() ?? '';
                errorMessage = '$typePart $codePart $messagePart'.trim();
              }
              stderr.writeln('SERVER_ERROR ${_sanitize(errorMessage)}');
              completeError(Exception(_sanitize(errorMessage)));
              break;
            default:
              break;
          }
        } catch (error, stackTrace) {
          completeError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        final safe = _sanitize(error.toString());
        stderr.writeln('STREAM_ERROR $safe');
        completeError(Exception(safe), stackTrace);
      },
      onDone: () {
        if (!done.isCompleted) {
          completeError(Exception('WebSocket closed before probe completion.'));
        }
      },
      cancelOnError: true,
    );

    await done.future.timeout(Duration(seconds: options.timeoutSeconds));

    final resolvedText =
        (finalText != null && finalText!.trim().isNotEmpty)
            ? finalText!.trim()
            : streamedText.toString().trim();
    stdout.writeln('FINAL_TEXT ${resolvedText.isEmpty ? '[empty]' : resolvedText}');

    await subscription.cancel();
    fallbackPromptTimer?.cancel();
    await channel.sink.close(ws_status.normalClosure);
  } on TimeoutException {
    stderr.writeln('Timed out waiting for response.');
    exitCode = 124;
  } catch (error, stackTrace) {
    stderr.writeln('PROBE_FAILED ${_sanitize(error.toString())}');
    stderr.writeln(_sanitize(stackTrace.toString()));
    exitCode = 1;
  } finally {
    fallbackPromptTimer?.cancel();
    await subscription?.cancel();
  }
}

Uri _normalizeWebSocketUri(Uri uri) {
  if (uri.scheme == 'wss' || uri.scheme == 'ws') {
    return uri;
  }
  if (uri.scheme == 'https') {
    return uri.replace(scheme: 'wss');
  }
  if (uri.scheme == 'http') {
    return uri.replace(scheme: 'ws');
  }
  return uri;
}

String _redactSensitiveParams(String url) {
  try {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    for (final key in const ['api-key', 'key', 'token']) {
      if (params.containsKey(key)) {
        params[key] = '[REDACTED]';
      }
    }
    return uri.replace(queryParameters: params).toString();
  } catch (_) {
    return _sanitize(url);
  }
}

Object? _redactJsonValue(Object? value) {
  if (value is Map) {
    return value.map(
      (key, nestedValue) {
        final keyString = key.toString();
        if (_isSensitiveKey(keyString)) {
          return MapEntry(keyString, '[REDACTED]');
        }
        return MapEntry(keyString, _redactJsonValue(nestedValue));
      },
    );
  }
  if (value is List) {
    return value.map(_redactJsonValue).toList(growable: false);
  }
  if (value is String) {
    return _sanitize(value);
  }
  return value;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'authorization' ||
      normalized == 'api-key' ||
      normalized == 'api_key' ||
      normalized == 'key' ||
      normalized == 'token' ||
      normalized == 'access_token';
}

String _prettyJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _sanitize(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'(api-key=)([^&\s]+)', caseSensitive: false),
        (match) => '${match.group(1)}[REDACTED]',
      )
      .replaceAllMapped(
        RegExp(r'(Bearer\s+)([^\s]+)', caseSensitive: false),
        (match) => '${match.group(1)}[REDACTED]',
      );
}

final class _ProbeOptions {
  final bool showHelp;
  final String keyPath;
  final String url;
  final String prompt;
  final String instructions;
  final int timeoutSeconds;

  const _ProbeOptions({
    required this.showHelp,
    required this.keyPath,
    required this.url,
    required this.prompt,
    required this.instructions,
    required this.timeoutSeconds,
  });

  factory _ProbeOptions.parse(List<String> args) {
    var showHelp = false;
    var keyPath = _defaultKeyPath;
    var url = _defaultUrl;
    var prompt = _defaultPrompt;
    var instructions = _defaultInstructions;
    var timeoutSeconds = _defaultTimeoutSeconds;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--key-file') {
        keyPath = _requireValue(args, ++index, arg);
      } else if (arg == '--url') {
        url = _requireValue(args, ++index, arg);
      } else if (arg == '--prompt') {
        prompt = _requireValue(args, ++index, arg);
      } else if (arg == '--instructions') {
        instructions = _requireValue(args, ++index, arg);
      } else if (arg == '--timeout-seconds') {
        final raw = _requireValue(args, ++index, arg);
        final parsed = int.tryParse(raw);
        if (parsed == null || parsed <= 0) {
          throw ArgumentError('Invalid value for $arg: $raw');
        }
        timeoutSeconds = parsed;
      } else {
        throw ArgumentError('Unknown argument: $arg');
      }
    }

    return _ProbeOptions(
      showHelp: showHelp,
      keyPath: keyPath,
      url: url,
      prompt: prompt,
      instructions: instructions,
      timeoutSeconds: timeoutSeconds,
    );
  }

  static String _requireValue(List<String> args, int index, String flag) {
    if (index >= args.length) {
      throw ArgumentError('Missing value for $flag');
    }
    return args[index];
  }
}

const _usage = '''
Azure OpenAI Realtime probe

Run with:
  dart run tool/aoai_realtime_probe.dart

Optional flags:
  --key-file /tmp/aoai_key.txt
  --url https://oas-playground-swe.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-realtime
  --prompt "Reply with exactly: AOAI probe success."
  --instructions "You are a connectivity probe..."
  --timeout-seconds 45
''';
