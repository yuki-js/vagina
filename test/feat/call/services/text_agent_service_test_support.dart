import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/services/virtual_filesystem_service.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

const testVoiceAgent = VoiceAgentInfo(
  id: 'voice-agent-1',
  name: 'Voice Agent',
  description: 'Test voice agent',
  voice: 'test-voice',
  prompt: 'Help the caller.',
  apiConfig: HostedVoiceAgentApiConfig(speedDialId: 'speed-dial-1'),
);

VaginaApiClient createTestApiClient(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return VaginaApiClient(dioOverride: dio);
}

NotepadService createTestNotepadService() {
  return NotepadService(
    VirtualFilesystemService(FakeVirtualFilesystemRepository()),
  );
}

RealtimeService createTestRealtimeService({String? sessionId}) {
  return RealtimeService(
    voiceAgent: testVoiceAgent,
    adapter: FakeRealtimeAdapter(sessionId: sessionId),
  );
}

final class FakeRealtimeAdapter implements RealtimeAdapter {
  final StreamController<RealtimeThread> _threadController =
      StreamController<RealtimeThread>.broadcast();
  final StreamController<RealtimeAdapterConnectionState> _stateController =
      StreamController<RealtimeAdapterConnectionState>.broadcast();
  final StreamController<RealtimeAdapterError> _errorController =
      StreamController<RealtimeAdapterError>.broadcast();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<void> _audioCompletedController =
      StreamController<void>.broadcast();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  @override
  final RealtimeThread thread = RealtimeThread(id: 'test-thread');

  @override
  final String? sessionId;

  RealtimeAdapterConnectionState _connectionState =
      const RealtimeAdapterConnectionState.idle();
  bool _disposed = false;
  final List<String> sentTexts = <String>[];
  final List<Uint8List> sentImages = <Uint8List>[];

  FakeRealtimeAdapter({this.sessionId});

  @override
  Stream<RealtimeThread> get threadUpdates => _threadController.stream;

  @override
  RealtimeAdapterConnectionState get connectionState => _connectionState;

  @override
  Stream<RealtimeAdapterConnectionState> get connectionStateUpdates =>
      _stateController.stream;

  @override
  Stream<RealtimeAdapterError> get errors => _errorController.stream;

  @override
  Stream<Uint8List> get assistantAudioStream => _audioController.stream;

  @override
  Stream<void> get assistantAudioCompleted => _audioCompletedController.stream;

  @override
  bool get isUserSpeaking => false;

  @override
  Stream<bool> get isUserSpeakingUpdates => _speakingController.stream;

  @override
  Future<void> connect(VoiceAgentApiConfig apiConfig, {String? voice}) async {
    _ensureNotDisposed();
    _connectionState = const RealtimeAdapterConnectionState.connected();
    _stateController.add(_connectionState);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _threadController.close();
    await _stateController.close();
    await _errorController.close();
    await _audioController.close();
    await _audioCompletedController.close();
    await _speakingController.close();
  }

  @override
  Future<void> bindAudioInput(Stream<Uint8List>? audioStream) async {
    _ensureNotDisposed();
  }

  @override
  Future<void> setAudioTurnMode(RealtimeAudioTurnMode mode) async {
    _ensureNotDisposed();
  }

  @override
  Future<void> registerTools(List<ToolDefinition> tools) async {
    _ensureNotDisposed();
  }

  @override
  Future<void> setInstructions(String instructions) async {
    _ensureNotDisposed();
  }

  @override
  Future<bool> applyProviderExtension(
    String extensionType,
    Map<String, dynamic> payload,
  ) async {
    _ensureNotDisposed();
    return false;
  }

  @override
  Future<String> sendAudioOneShot(Uint8List audioBytes) {
    throw UnimplementedError('sendAudioOneShot() is not used in this test.');
  }

  @override
  Future<String> sendText(String text) async {
    _ensureNotDisposed();
    sentTexts.add(text);
    return 'text-${sentTexts.length}';
  }

  @override
  Future<String> sendImage(Uint8List imageBytes) async {
    _ensureNotDisposed();
    sentImages.add(Uint8List.fromList(imageBytes));
    return 'image-${sentImages.length}';
  }

  @override
  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  }) {
    throw UnimplementedError('sendFunctionOutput() is not used in this test.');
  }

  @override
  Future<void> interrupt() async {
    _ensureNotDisposed();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('FakeRealtimeAdapter has been disposed.');
    }
  }
}

final class FakeVirtualFilesystemRepository
    implements VirtualFilesystemRepository {
  final Map<String, VirtualFile> _files = <String, VirtualFile>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async {
    return _files[path];
  }

  @override
  Future<void> write(VirtualFile file) async {
    _files[file.path] = file;
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final file = _files.remove(fromPath);
    if (file != null) {
      _files[toPath] = VirtualFile(path: toPath, content: file.content);
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return const <String>[];
  }
}
