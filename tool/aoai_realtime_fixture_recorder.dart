import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

const _defaultKeyPath = '/tmp/aoai_key.txt';
const _defaultUrl =
    'https://oas-playground-swe.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-realtime';
const _defaultTimeoutSeconds = 60;

/// Records OpenAI Realtime API interaction to a fixture file for testing.
///
/// Usage:
///   dart run tool/aoai_realtime_fixture_recorder.dart \
///     --scenario text-only \
///     --output test/fixtures/oai_realtime/text_conversation.json
///
///   dart run tool/aoai_realtime_fixture_recorder.dart \
///     --scenario audio-response \
///     --output test/fixtures/oai_realtime/audio_conversation.json
Future<void> main(List<String> args) async {
  final options = _RecorderOptions.parse(args);

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

  final recorder = _FixtureRecorder(
    scenario: options.scenario,
    outputPath: options.outputPath,
  );

  try {
    stdout.writeln('Connecting to Azure OpenAI Realtime...');
    stdout.writeln('Scenario: ${options.scenario}');
    stdout.writeln('Output: ${options.outputPath}');

    final channel = IOWebSocketChannel.connect(targetUri);
    await channel.ready.timeout(Duration(seconds: options.timeoutSeconds));
    stdout.writeln('Connected');

    final done = Completer<void>();
    StreamSubscription<dynamic>? subscription;
    Timer? scenarioTimer;

    void cleanup() {
      scenarioTimer?.cancel();
      subscription?.cancel();
    }

    subscription = channel.stream.listen(
      (data) async {
        try {
          final decoded = data is String ? jsonDecode(data) : data;
          if (decoded is! Map) {
            return;
          }

          final message = Map<String, dynamic>.from(decoded);
          final type = message['type'] as String? ?? 'unknown';

          // Record received event
          recorder.recordReceived(message);
          stdout.writeln('RECV $type');

          // Handle scenario logic
          switch (type) {
            case 'session.created':
              scenarioTimer?.cancel();
              scenarioTimer = Timer(const Duration(milliseconds: 500), () async {
                try {
                  await _executeScenario(
                    channel,
                    recorder,
                    options.scenario,
                  );
                } catch (error, stackTrace) {
                  stderr.writeln('Scenario error: $error');
                  stderr.writeln(stackTrace);
                  if (!done.isCompleted) {
                    done.completeError(error, stackTrace);
                  }
                }
              });
              break;
            case 'response.done':
              stdout.writeln('Response complete, wrapping up...');
              scenarioTimer?.cancel();
              scenarioTimer = Timer(const Duration(seconds: 1), () {
                if (!done.isCompleted) {
                  done.complete();
                }
              });
              break;
            case 'error':
              final error = message['error'];
              stderr.writeln('Server error: $error');
              if (!done.isCompleted) {
                done.completeError(Exception('Server error: $error'));
              }
              break;
          }
        } catch (error, stackTrace) {
          stderr.writeln('Handle error: $error');
          if (!done.isCompleted) {
            done.completeError(error, stackTrace);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        stderr.writeln('Stream error: $error');
        if (!done.isCompleted) {
          done.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: true,
    );

    await done.future.timeout(Duration(seconds: options.timeoutSeconds));

    await subscription.cancel();
    scenarioTimer?.cancel();
    await channel.sink.close(ws_status.normalClosure);

    // Write fixture file
    await recorder.writeFixture();
    stdout.writeln('\nFixture recorded to: ${options.outputPath}');
    stdout.writeln('Events: ${recorder.eventCount}');
  } on TimeoutException {
    stderr.writeln('Timed out waiting for scenario completion.');
    exitCode = 124;
  } catch (error, stackTrace) {
    stderr.writeln('Recording failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<void> _executeScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
  String scenario,
) async {
  switch (scenario) {
    case 'text-only':
      await _runTextOnlyScenario(channel, recorder);
      break;
    case 'audio-response':
      await _runAudioResponseScenario(channel, recorder);
      break;
    case 'text-with-audio':
      await _runTextWithAudioScenario(channel, recorder);
      break;
    case 'function-call':
      await _runFunctionCallScenario(channel, recorder);
      break;
    default:
      throw ArgumentError('Unknown scenario: $scenario');
  }
}

Future<void> _runTextOnlyScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
) async {
  // Configure session for text-only
  final sessionUpdate = {
    'type': 'session.update',
    'session': {
      'modalities': ['text'],
      'instructions':
          'You are a helpful assistant. Keep your responses very brief (1-2 sentences).',
    },
  };
  recorder.recordSent(sessionUpdate);
  channel.sink.add(jsonEncode(sessionUpdate));
  stdout.writeln('SEND session.update (text-only)');

  await Future<void>.delayed(const Duration(milliseconds: 200));

  // Send a simple message
  final itemCreate = {
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text': 'What is 2 + 2? Just give me the answer.',
        },
      ],
    },
  };
  recorder.recordSent(itemCreate);
  channel.sink.add(jsonEncode(itemCreate));
  stdout.writeln('SEND conversation.item.create');

  await Future<void>.delayed(const Duration(milliseconds: 100));

  final responseCreate = {
    'type': 'response.create',
    'response': {
      'modalities': ['text'],
    },
  };
  recorder.recordSent(responseCreate);
  channel.sink.add(jsonEncode(responseCreate));
  stdout.writeln('SEND response.create');
}

Future<void> _runAudioResponseScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
) async {
  // Configure session for text input, audio output
  final sessionUpdate = {
    'type': 'session.update',
    'session': {
      'modalities': ['text', 'audio'],
      'instructions':
          'You are a helpful assistant. Keep your responses very brief.',
      'voice': 'alloy',
    },
  };
  recorder.recordSent(sessionUpdate);
  channel.sink.add(jsonEncode(sessionUpdate));
  stdout.writeln('SEND session.update (audio-response)');

  await Future<void>.delayed(const Duration(milliseconds: 200));

  final itemCreate = {
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text': 'Say hello.',
        },
      ],
    },
  };
  recorder.recordSent(itemCreate);
  channel.sink.add(jsonEncode(itemCreate));
  stdout.writeln('SEND conversation.item.create');

  await Future<void>.delayed(const Duration(milliseconds: 100));

  final responseCreate = {
    'type': 'response.create',
    'response': {
      'modalities': ['text', 'audio'],
    },
  };
  recorder.recordSent(responseCreate);
  channel.sink.add(jsonEncode(responseCreate));
  stdout.writeln('SEND response.create');
}

Future<void> _runTextWithAudioScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
) async {
  // Configure session for both text and audio
  final sessionUpdate = {
    'type': 'session.update',
    'session': {
      'modalities': ['text', 'audio'],
      'instructions': 'You are a helpful assistant.',
      'voice': 'alloy',
      'input_audio_transcription': {
        'model': 'whisper-1',
      },
    },
  };
  recorder.recordSent(sessionUpdate);
  channel.sink.add(jsonEncode(sessionUpdate));
  stdout.writeln('SEND session.update (text-with-audio)');

  await Future<void>.delayed(const Duration(milliseconds: 200));

  final itemCreate = {
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text': 'Tell me a one-sentence fact.',
        },
      ],
    },
  };
  recorder.recordSent(itemCreate);
  channel.sink.add(jsonEncode(itemCreate));
  stdout.writeln('SEND conversation.item.create');

  await Future<void>.delayed(const Duration(milliseconds: 100));

  final responseCreate = {
    'type': 'response.create',
    'response': {
      'modalities': ['text', 'audio'],
    },
  };
  recorder.recordSent(responseCreate);
  channel.sink.add(jsonEncode(responseCreate));
  stdout.writeln('SEND response.create');
}

Future<void> _runFunctionCallScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
) async {
  // Configure session with function
  final sessionUpdate = {
    'type': 'session.update',
    'session': {
      'modalities': ['text'],
      'instructions': 'You are a helpful assistant that can get the weather.',
      'tools': [
        {
          'type': 'function',
          'name': 'get_weather',
          'description': 'Get the current weather for a location',
          'parameters': {
            'type': 'object',
            'properties': {
              'location': {
                'type': 'string',
                'description': 'City name, e.g. San Francisco',
              },
            },
            'required': ['location'],
          },
        },
      ],
    },
  };
  recorder.recordSent(sessionUpdate);
  channel.sink.add(jsonEncode(sessionUpdate));
  stdout.writeln('SEND session.update (function-call)');

  await Future<void>.delayed(const Duration(milliseconds: 200));

  final itemCreate = {
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text': 'What is the weather in Tokyo?',
        },
      ],
    },
  };
  recorder.recordSent(itemCreate);
  channel.sink.add(jsonEncode(itemCreate));
  stdout.writeln('SEND conversation.item.create');

  await Future<void>.delayed(const Duration(milliseconds: 100));

  final responseCreate = {
    'type': 'response.create',
    'response': {
      'modalities': ['text'],
    },
  };
  recorder.recordSent(responseCreate);
  channel.sink.add(jsonEncode(responseCreate));
  stdout.writeln('SEND response.create');
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

final class _RecorderOptions {
  final bool showHelp;
  final String keyPath;
  final String url;
  final String scenario;
  final String outputPath;
  final int timeoutSeconds;

  const _RecorderOptions({
    required this.showHelp,
    required this.keyPath,
    required this.url,
    required this.scenario,
    required this.outputPath,
    required this.timeoutSeconds,
  });

  factory _RecorderOptions.parse(List<String> args) {
    var showHelp = false;
    var keyPath = _defaultKeyPath;
    var url = _defaultUrl;
    var scenario = 'text-only';
    var outputPath = 'test/fixtures/oai_realtime/recorded_session.json';
    var timeoutSeconds = _defaultTimeoutSeconds;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--key-file') {
        keyPath = _requireValue(args, ++index, arg);
      } else if (arg == '--url') {
        url = _requireValue(args, ++index, arg);
      } else if (arg == '--scenario') {
        scenario = _requireValue(args, ++index, arg);
      } else if (arg == '--output') {
        outputPath = _requireValue(args, ++index, arg);
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

    return _RecorderOptions(
      showHelp: showHelp,
      keyPath: keyPath,
      url: url,
      scenario: scenario,
      outputPath: outputPath,
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

final class _FixtureRecorder {
  final String scenario;
  final String outputPath;
  final List<Map<String, dynamic>> _events = [];

  _FixtureRecorder({
    required this.scenario,
    required this.outputPath,
  });

  int get eventCount => _events.length;

  void recordSent(Map<String, dynamic> payload) {
    _events.add({
      'direction': 'sent',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  void recordReceived(Map<String, dynamic> payload) {
    _events.add({
      'direction': 'received',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  Future<void> writeFixture() async {
    final fixture = {
      'scenario': scenario,
      'recorded_at': DateTime.now().toIso8601String(),
      'event_count': _events.length,
      'events': _events,
    };

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(fixture),
    );
  }
}

const _usage = '''
Azure OpenAI Realtime fixture recorder

Records a complete API interaction to a fixture file for testing.

Usage:
  dart run tool/aoai_realtime_fixture_recorder.dart [options]

Options:
  --key-file PATH       Path to API key file (default: /tmp/aoai_key.txt)
  --url URL             API endpoint URL
  --scenario NAME       Scenario to record (default: text-only)
                        Options: text-only, audio-response, text-with-audio, function-call
  --output PATH         Output fixture file path
                        (default: test/fixtures/oai_realtime/recorded_session.json)
  --timeout-seconds N   Timeout in seconds (default: 60)
  --help, -h            Show this help

Examples:
  # Record a text-only conversation
  dart run tool/aoai_realtime_fixture_recorder.dart \\
    --scenario text-only \\
    --output test/fixtures/oai_realtime/text_conversation.json

  # Record an audio response scenario
  dart run tool/aoai_realtime_fixture_recorder.dart \\
    --scenario audio-response \\
    --output test/fixtures/oai_realtime/audio_conversation.json

  # Record a function call scenario
  dart run tool/aoai_realtime_fixture_recorder.dart \\
    --scenario function-call \\
    --output test/fixtures/oai_realtime/function_call.json
''';
