import 'dart:typed_data';

import 'package:vagina/feat/callv2/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/callv2/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'realtime/oai/realtime_adapter.dart';
import 'realtime/realtime_adapter.dart';

/// Session-scoped realtime backing service for a single call.
final class RealtimeService implements SubService {
  final VoiceAgentInfo voiceAgent;
  late final RealtimeAdapter _adapter;

  bool _started = false;

  RealtimeService({required this.voiceAgent});

  RealtimeThread get thread => _adapter.thread;

  Stream<RealtimeThread> get threadUpdates => _adapter.threadUpdates;

  Stream<RealtimeAdapterConnectionState> get connectionStates =>
      _adapter.connectionStates;

  Stream<RealtimeAdapterError> get errors => _adapter.errors;

  bool get isConnected => _adapter.isConnected;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }

    _adapter = _createAdapter(voiceAgent.apiConfig);

    _started = true;
    try {
      await _adapter.connect(
        voiceAgent.apiConfig,
        voice: voiceAgent.voice,
        instructions: voiceAgent.prompt,
      );
    } catch (_) {
      _started = false;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!_started) {
      return;
    }
    await _adapter.disconnect();
  }

  // ---------------------------------------------------------------------------
  // Audio input / output
  // ---------------------------------------------------------------------------

  /// Start forwarding a PCM audio stream to the model.
  Future<void> bindAudioInput(Stream<Uint8List> audioStream) {
    return _adapter.bindAudioInput(audioStream);
  }

  /// Stop forwarding audio.
  Future<void> unbindAudioInput() {
    return _adapter.unbindAudioInput();
  }

  /// Provider-decoded assistant PCM output stream.
  Stream<Uint8List> get assistantAudioStream => _adapter.assistantAudioStream;

  /// Completion signal for the current assistant audio response.
  Stream<void> get assistantAudioCompleted => _adapter.assistantAudioCompleted;

  /// Emits the current VAD speaking state whenever it changes.
  Stream<bool> get userSpeakingStates => _adapter.userSpeakingStates;

  /// Whether VAD currently considers the user to be speaking.
  bool get isUserSpeaking => _adapter.isUserSpeaking;

  // ---------------------------------------------------------------------------
  // Tool configuration
  // ---------------------------------------------------------------------------

  Future<void> registerTools(List<ToolDefinition> tools) {
    return _adapter.registerTools(tools);
  }

  // ---------------------------------------------------------------------------
  // User content
  // ---------------------------------------------------------------------------

  Future<String> sendText(String text) {
    return _adapter.sendText(text);
  }

  Future<String> sendImage(String dataUri) {
    return _adapter.sendImage(dataUri);
  }

  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  }) {
    return _adapter.sendFunctionOutput(
      callId: callId,
      output: output,
      disposition: disposition,
      errorMessage: errorMessage,
    );
  }

  void cancelFunctionCalls({
    Set<String> itemIds = const <String>{},
    Set<String> callIds = const <String>{},
  }) {
    _adapter.cancelFunctionCalls(itemIds: itemIds, callIds: callIds);
  }

  // ---------------------------------------------------------------------------
  // Response control
  // ---------------------------------------------------------------------------

  /// Interrupt the model's current response.
  Future<void> interrupt() {
    return _adapter.interrupt();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    _started = false;
    await _adapter.dispose();
  }

  // ---------------------------------------------------------------------------
  // Adapter factory
  // ---------------------------------------------------------------------------

  static RealtimeAdapter _createAdapter(VoiceAgentApiConfig apiConfig) {
    return switch (apiConfig) {
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.openai
      ) ||
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.azureOpenAi
      ) =>
        OaiRealtimeAdapter(),
      HostedVoiceAgentApiConfig() => throw UnsupportedError(
          'Hosted voice agents are not wired to RealtimeAdapter yet.',
        ),
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.gemini
      ) =>
        throw UnsupportedError(
          'Gemini adapter is not implemented yet.',
        ),
      _ => throw UnsupportedError(
          'Unsupported voice agent api config for realtime service.',
        ),
    };
  }

  // _isOpenAiFamily and _isGemini removed; providerType enum is now used.
}
