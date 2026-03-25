// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_player_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:taudio/taudio.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/virtual_file.dart';

const MethodChannel _justAudioMethodsChannel =
    MethodChannel('com.ryanheise.just_audio.methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallService audio wiring', () {
    late RecordPlatform originalRecordPlatform;
    late FlutterSoundPlayerPlatform originalPlayerPlatform;
    late _FakeRecordPlatform fakeRecordPlatform;
    late _FakeFlutterSoundPlayerPlatform fakePlayerPlatform;
    late HttpServer server;
    late _RealtimeSocketHarness harness;
    late _FakeVirtualFilesystemRepository filesystemRepository;
    late _FakeCallSessionRepository sessionRepository;
    late CallService service;

    setUp(() async {
      originalRecordPlatform = RecordPlatform.instance;
      originalPlayerPlatform = FlutterSoundPlayerPlatform.instance;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _justAudioMethodsChannel,
        (methodCall) async {
          return null;
        },
      );

      fakeRecordPlatform = _FakeRecordPlatform();
      fakePlayerPlatform = _FakeFlutterSoundPlayerPlatform();
      RecordPlatform.instance = fakeRecordPlatform;
      FlutterSoundPlayerPlatform.instance = fakePlayerPlatform;

      harness = _RealtimeSocketHarness();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serveHarness(server, harness));
      filesystemRepository = _FakeVirtualFilesystemRepository();
      sessionRepository = _FakeCallSessionRepository();

      service = CallService(
        filesystemRepository: filesystemRepository,
        sessionRepository: sessionRepository,
        enableFeedback: false,
      );
      service.setTextAgents(const <TextAgentInfo>[]);
      service.setVoiceAgent(
        VoiceAgentInfo(
          id: 'voice-agent',
          name: 'Test Agent',
          description: 'Audio wiring test agent',
          voice: 'alloy',
          prompt: 'Be brief.',
          apiConfig: SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: 'ws://127.0.0.1:${server.port}/v1/realtime',
            apiKey: 'test-key',
            model: 'gpt-realtime-test',
          ),
          enabledTools: const <String>[],
        ),
      );
    });

    tearDown(() async {
      if (service.state != CallState.uninitialized &&
          service.state != CallState.disposed) {
        await service.endCall();
      }
      await harness.dispose();
      await server.close(force: true);
      RecordPlatform.instance = originalRecordPlatform;
      FlutterSoundPlayerPlatform.instance = originalPlayerPlatform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_justAudioMethodsChannel, null);
    });

    test('pipes recorder PCM into realtime and assistant PCM into playback',
        () async {
      await service.startCall();

      final firstSessionUpdate = await harness.waitForCommand('session.update');
      expect(firstSessionUpdate['session'], isA<Map<String, dynamic>>());
      expect(
        firstSessionUpdate['session']['tools'],
        isA<List<dynamic>>(),
      );
      expect(firstSessionUpdate['session']['tools'], isEmpty);
      expect(firstSessionUpdate['session']['tool_choice'], equals('none'));

      fakeRecordPlatform.emitAudio(const <int>[1, 2, 3, 4]);

      final appendCommand =
          await harness.waitForCommand('input_audio_buffer.append');
      final appendedAudio = base64Decode(appendCommand['audio']! as String)
          .toList(growable: false);
      expect(appendedAudio, orderedEquals(const <int>[1, 2, 3, 4]));

      final assistantBytes = Uint8List.fromList(const <int>[5, 6, 7, 8]);
      harness.sendEvent({
        'type': 'response.output_audio.delta',
        'event_id': 'evt_audio_delta',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'output_index': 0,
        'content_index': 0,
        'delta': base64Encode(assistantBytes),
      });
      harness.sendEvent({
        'type': 'response.output_audio.done',
        'event_id': 'evt_audio_done',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'output_index': 0,
        'content_index': 0,
      });

      await _eventually(() {
        expect(fakePlayerPlatform.feedChunks, hasLength(1));
      });

      expect(
        fakePlayerPlatform.feedChunks.single,
        orderedEquals(assistantBytes),
      );
      expect(fakePlayerPlatform.startPlayerFromStreamCalls, 1);
      expect(service.state, CallState.active);
    });

    test('speech start interrupts playback and emits speaking state changes',
        () async {
      await service.startCall();
      await harness.waitForCommand('session.update');
      final realtimeService = service.realtimeService!;
      final speakingStates = <bool>[];
      final speakingStateSubscription =
          realtimeService.userSpeakingStates.listen(speakingStates.add);
      final assistantBytes = Uint8List(AppConfig.minAudioBufferSizeBeforeStart)
        ..fillRange(0, AppConfig.minAudioBufferSizeBeforeStart, 7);

      harness.sendEvent({
        'type': 'response.output_audio.delta',
        'event_id': 'evt_audio_delta_speech_interrupt',
        'response_id': 'resp_speech_interrupt',
        'item_id': 'assistant_item_speech_interrupt',
        'output_index': 0,
        'content_index': 0,
        'delta': base64Encode(assistantBytes),
      });
      harness.sendEvent({
        'type': 'response.output_audio.done',
        'event_id': 'evt_audio_done_speech_interrupt',
        'response_id': 'resp_speech_interrupt',
        'item_id': 'assistant_item_speech_interrupt',
        'output_index': 0,
        'content_index': 0,
      });

      await _eventually(() {
        expect(fakePlayerPlatform.startPlayerFromStreamCalls, 1);
      });

      final stopCallsBeforeSpeechStarted = fakePlayerPlatform.stopPlayerCalls;
      harness.sendEvent({
        'type': 'input_audio_buffer.speech_started',
        'event_id': 'evt_speech_started',
        'item_id': 'user_item_speech_started',
        'audio_start_ms': 120,
      });

      await _eventually(() {
        expect(
          fakePlayerPlatform.stopPlayerCalls,
          stopCallsBeforeSpeechStarted + 1,
        );
      });

      final cancelCommand = await harness.waitForCommand('response.cancel');
      expect(cancelCommand['type'], equals('response.cancel'));
      final clearCommand =
          await harness.waitForCommand('output_audio_buffer.clear');
      expect(clearCommand['type'], equals('output_audio_buffer.clear'));
      expect(realtimeService.isUserSpeaking, isTrue);
      expect(speakingStates, contains(true));

      harness.sendEvent({
        'type': 'input_audio_buffer.speech_stopped',
        'event_id': 'evt_speech_stopped',
        'item_id': 'user_item_speech_started',
        'audio_end_ms': 240,
      });

      await _eventually(() {
        expect(realtimeService.isUserSpeaking, isFalse);
      });
      expect(speakingStates, containsAllInOrder(const <bool>[true, false]));

      await speakingStateSubscription.cancel();
    });

    test('persists saved session with notepad tabs and end context', () async {
      await service.startCall();
      await harness.waitForCommand('session.update');

      harness.sendEvent({
        'type': 'conversation.item.created',
        'event_id': 'evt_user_message_created',
        'previous_item_id': null,
        'item': {
          'id': 'user_item_1',
          'object': 'realtime.item',
          'type': 'message',
          'status': 'completed',
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': 'Need a summary',
            },
          ],
        },
      });
      harness.sendEvent({
        'type': 'response.output_item.done',
        'event_id': 'evt_assistant_message_done',
        'response_id': 'resp_session_save',
        'output_index': 0,
        'item': {
          'id': 'assistant_item_1',
          'object': 'realtime.item',
          'type': 'message',
          'status': 'completed',
          'role': 'assistant',
          'content': [
            {
              'type': 'output_text',
              'text': 'Summary ready',
            },
          ],
        },
      });

      await _eventually(() {
        expect(service.realtimeService!.thread.items, hasLength(2));
      });

      await service.notepadService.open('/notes.md', '# Session Notes');
      await service.endCall(endContext: 'tool completed the task');

      expect(service.state, CallState.disposed);
      expect(sessionRepository.savedSessions, hasLength(1));
      expect(filesystemRepository.files['/notes.md']?.content, '# Session Notes');

      final savedSession = sessionRepository.savedSessions.single;
      expect(savedSession.speedDialId, equals('voice-agent'));
      expect(savedSession.endContext, equals('tool completed the task'));
      expect(savedSession.endTime, isNotNull);
      expect(savedSession.notepadTabs, hasLength(1));
      expect(savedSession.notepadTabs!.single.title, equals('notes.md'));
      expect(savedSession.notepadTabs!.single.content, equals('# Session Notes'));
      expect(savedSession.notepadTabs!.single.mimeType, equals('text/markdown'));

      final decodedMessages = savedSession.chatMessages
          .map((value) => jsonDecode(value) as Map<String, dynamic>)
          .toList(growable: false);
      expect(
        decodedMessages.map((message) => message['role']).toList(growable: false),
        orderedEquals(const <String>['user', 'assistant']),
      );
      expect(
        decodedMessages
            .map((message) => message['content'])
            .toList(growable: false),
        orderedEquals(const <String>['Need a summary', 'Summary ready']),
      );
    });
  });
}

Future<void> _serveHarness(
  HttpServer server,
  _RealtimeSocketHarness harness,
) async {
  await for (final request in server) {
    final socket = await WebSocketTransformer.upgrade(request);
    harness.attach(socket);
  }
}

Future<void> _eventually(
  void Function() assertion, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  StackTrace? lastStackTrace;

  while (DateTime.now().isBefore(deadline)) {
    try {
      assertion();
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}

final class _RealtimeSocketHarness {
  final List<Map<String, dynamic>> _commands = <Map<String, dynamic>>[];
  final StreamController<Map<String, dynamic>> _commandController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocket? _socket;

  void attach(WebSocket socket) {
    _socket = socket;
    socket.listen((message) {
      final payload =
          Map<String, dynamic>.from(jsonDecode(message as String) as Map);
      _commands.add(payload);
      if (!_commandController.isClosed) {
        _commandController.add(payload);
      }
    });

    sendEvent({
      'type': 'session.created',
      'event_id': 'evt_session_created',
      'session': {
        'id': 'sess_1',
        'object': 'realtime.session',
        'model': 'gpt-realtime-test',
        'voice': 'alloy',
        'instructions': 'Be brief.',
      },
    });
    sendEvent({
      'type': 'conversation.created',
      'event_id': 'evt_conversation_created',
      'conversation': {
        'id': 'conv_1',
        'object': 'realtime.conversation',
      },
    });
  }

  Future<Map<String, dynamic>> waitForCommand(String type) async {
    for (final command in _commands) {
      if (command['type'] == type) {
        return command;
      }
    }
    return _commandController.stream.firstWhere(
      (command) => command['type'] == type,
    );
  }

  void sendEvent(Map<String, dynamic> payload) {
    _socket?.add(jsonEncode(payload));
  }

  Future<void> dispose() async {
    await _socket?.close();
    await _commandController.close();
  }
}

final class _FakeRecordPlatform extends RecordPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<RecordState> _stateController =
      StreamController<RecordState>.broadcast();

  bool isRecordingValue = false;

  void emitAudio(List<int> bytes) {
    _audioController.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    return true;
  }

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => isRecordingValue;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> start(String recorderId, RecordConfig config,
      {required String path}) async {
    throw UnimplementedError('File recording is not used by CallService.');
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    isRecordingValue = true;
    _stateController.add(RecordState.record);
    return _audioController.stream;
  }

  @override
  Future<String?> stop(String recorderId) async {
    isRecordingValue = false;
    _stateController.add(RecordState.stop);
    return null;
  }

  @override
  Future<void> cancel(String recorderId) async {
    isRecordingValue = false;
    _stateController.add(RecordState.stop);
  }

  @override
  Future<void> dispose(String recorderId) async {
    isRecordingValue = false;
    await _audioController.close();
    await _stateController.close();
  }

  @override
  Future<Amplitude> getAmplitude(String recorderId) async {
    return Amplitude(current: -24.0, max: 0.0);
  }

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async {
    return true;
  }

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async {
    return const <InputDevice>[];
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) {
    return _stateController.stream;
  }
}

final class _FakeFlutterSoundPlayerPlatform extends FlutterSoundPlayerPlatform
    with MockPlatformInterfaceMixin {
  final List<Uint8List> feedChunks = <Uint8List>[];

  int startPlayerFromStreamCalls = 0;
  int stopPlayerCalls = 0;

  @override
  Future<bool> initPlugin() async => true;

  @override
  Future<void>? resetPlugin(FlutterSoundPlayerCallback callback) async {}

  @override
  Future<int> openPlayer(
    FlutterSoundPlayerCallback callback, {
    required Level logLevel,
  }) async {
    callback.openPlayerCompleted(PlayerState.isStopped.index, true);
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> startPlayerFromStream(
    FlutterSoundPlayerCallback callback, {
    Codec codec = Codec.pcm16,
    bool interleaved = true,
    int numChannels = 1,
    int sampleRate = 16000,
    int bufferSize = 8192,
  }) async {
    startPlayerFromStreamCalls += 1;
    callback.startPlayerCompleted(PlayerState.isPlaying.index, true, 0);
    return PlayerState.isPlaying.index;
  }

  @override
  Future<int> feed(
    FlutterSoundPlayerCallback callback, {
    required Uint8List data,
  }) async {
    feedChunks.add(Uint8List.fromList(data));
    return data.length;
  }

  @override
  Future<int> stopPlayer(FlutterSoundPlayerCallback callback) async {
    stopPlayerCalls += 1;
    callback.stopPlayerCompleted(PlayerState.isStopped.index, true);
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> closePlayer(FlutterSoundPlayerCallback callback) async {
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> setVolume(
    FlutterSoundPlayerCallback callback, {
    required double volume,
  }) async {
    return PlayerState.isStopped.index;
  }
}

final class _FakeCallSessionRepository implements CallSessionRepository {
  final List<CallSession> savedSessions = <CallSession>[];

  @override
  Future<void> save(CallSession session) async {
    savedSessions.removeWhere((existing) => existing.id == session.id);
    savedSessions.add(session);
  }

  @override
  Future<List<CallSession>> getAll() async => List<CallSession>.from(savedSessions);

  @override
  Future<CallSession?> getById(String id) async {
    for (final session in savedSessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<bool> delete(String id) async {
    final beforeLength = savedSessions.length;
    savedSessions.removeWhere((session) => session.id == id);
    return savedSessions.length != beforeLength;
  }

  @override
  Future<void> deleteAll() async {
    savedSessions.clear();
  }
}

final class _FakeVirtualFilesystemRepository
    implements VirtualFilesystemRepository {
  final Map<String, VirtualFile> files = <String, VirtualFile>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async => files[path];

  @override
  Future<void> write(VirtualFile file) async {
    files[file.path] = file;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final file = files.remove(fromPath);
    if (file != null) {
      files[toPath] = VirtualFile(path: toPath, content: file.content);
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return files.keys
        .where((key) => key.startsWith(path))
        .map((key) => key.substring(1))
        .toList(growable: false);
  }
}
