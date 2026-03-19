import 'dart:typed_data';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'realtime/oai/realtime_adapter.dart';
import 'realtime/realtime_adapter.dart';

/// Session-scoped realtime backing service for a single call.
final class RealtimeService {
  final VoiceAgentInfo voiceAgent;
  final RealtimeAdapter _adapter;

  bool _started = false;

  RealtimeService({
    required this.voiceAgent,
    RealtimeAdapter? adapter,
  }) : _adapter = adapter ?? _createAdapter(voiceAgent.apiConfig);

  RealtimeThread get thread => _adapter.thread;

  Stream<RealtimeThread> get threadUpdates => _adapter.threadUpdates;

  Stream<RealtimeAdapterConnectionState> get connectionStates =>
      _adapter.connectionStates;

  Stream<RealtimeAdapterError> get errors => _adapter.errors;

  bool get isConnected => _adapter.isConnected;

  /// Connect and configure the session.
  ///
  /// Voice, instructions, and all provider-specific defaults (audio format,
  /// VAD, transcription model) are handled inside the adapter.
  Future<void> start() async {
    if (_started) {
      return;
    }

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
  // Audio input
  // ---------------------------------------------------------------------------

  /// Start forwarding a PCM audio stream to the model.
  Future<void> bindAudioInput(Stream<Uint8List> audioStream) {
    return _adapter.bindAudioInput(audioStream);
  }

  /// Stop forwarding audio.
  Future<void> unbindAudioInput() {
    return _adapter.unbindAudioInput();
  }

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
  }) {
    return _adapter.sendFunctionOutput(callId: callId, output: output);
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

  Future<void> dispose() async {
    _started = false;
    await _adapter.dispose();
  }

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  static RealtimeAdapter _createAdapter(VoiceAgentApiConfig apiConfig) {
    return switch (apiConfig) {
      SelfhostedVoiceAgentApiConfig(provider: final provider)
          when _isOpenAiFamily(provider) => OaiRealtimeAdapter(),
      HostedVoiceAgentApiConfig() => throw UnsupportedError(
          'Hosted voice agents are not wired to RealtimeAdapter yet.',
        ),
      SelfhostedVoiceAgentApiConfig(provider: final provider)
          when _isGemini(provider) => throw UnsupportedError(
              'Gemini adapter is not implemented yet.',
            ),
      _ => throw UnsupportedError(
          'Unsupported voice agent api config for realtime service.',
        ),
    };
  }

  static bool _isOpenAiFamily(String provider) {
    final normalized = provider.toLowerCase();
    return normalized == 'openai' ||
        normalized == 'open_ai' ||
        normalized == 'open-ai' ||
        normalized == 'azure' ||
        normalized == 'azureopenai' ||
        normalized == 'azure_openai' ||
        normalized == 'azure-openai';
  }

  static bool _isGemini(String provider) {
    final normalized = provider.toLowerCase();
    return normalized == 'gemini' || normalized == 'google';
  }
}
