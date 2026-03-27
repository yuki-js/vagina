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
final class RealtimeService extends SubService {
  final VoiceAgentInfo voiceAgent;
  late final RealtimeAdapter _adapter;

  RealtimeService({required this.voiceAgent}) {
    _adapter = _createAdapter(voiceAgent.apiConfig);
  }

  RealtimeThread get thread => _adapter.thread;

  Stream<RealtimeThread> get threadUpdates => _adapter.threadUpdates;

  Stream<RealtimeAdapterConnectionState> get connectionStates =>
      _adapter.connectionStates;

  Stream<RealtimeAdapterError> get errors => _adapter.errors;

  bool get isConnected => _adapter.isConnected;

  @override
  Future<void> start() async {
    await super.start();

    logger.info(
        'Starting RealtimeService for provider: ${voiceAgent.apiConfig.runtimeType}');

    try {
      logger.info('Connecting to realtime API with voice: ${voiceAgent.voice}');
      await _adapter.connect(
        voiceAgent.apiConfig,
        voice: voiceAgent.voice,
        instructions: voiceAgent.prompt,
      );
      logger.info('Successfully connected to realtime API');
    } catch (e, stackTrace) {
      logger.severe('Failed to connect to realtime API', e, stackTrace);
      // Reset _started flag on connection failure
      await dispose();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    ensureNotDisposed();
    if (!isStarted) {
      logger.fine('Disconnect called but service not started');
      return;
    }
    logger.info('Disconnecting from realtime API');
    await _adapter.disconnect();
  }

  // ---------------------------------------------------------------------------
  // Audio input / output
  // ---------------------------------------------------------------------------

  /// Start forwarding a PCM audio stream to the model.
  Future<void> bindAudioInput(Stream<Uint8List> audioStream) {
    logger.info('Binding audio input stream to realtime adapter');
    return _adapter.bindAudioInput(audioStream);
  }

  /// Stop forwarding audio.
  Future<void> unbindAudioInput() {
    logger.info('Unbinding audio input stream from realtime adapter');
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
    logger.info('Registering ${tools.length} tools with realtime adapter');
    logger.fine('Tool names: ${tools.map((t) => t.toolKey).join(", ")}');
    return _adapter.registerTools(tools);
  }

  // ---------------------------------------------------------------------------
  // User content
  // ---------------------------------------------------------------------------

  Future<String> sendText(String text) {
    logger.info('Sending text message (${text.length} chars)');
    logger.fine(
        'Text content: ${text.length > 100 ? "${text.substring(0, 100)}..." : text}');
    return _adapter.sendText(text);
  }

  Future<String> sendImage(String dataUri) {
    logger.info('Sending image (${dataUri.length} bytes)');
    return _adapter.sendImage(dataUri);
  }

  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  }) {
    logger.info(
        'Sending function output for call: $callId, disposition: $disposition');
    if (errorMessage != null) {
      logger.warning('Function output contains error: $errorMessage');
    }
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
    logger.info(
        'Cancelling function calls: ${itemIds.length} items, ${callIds.length} calls');
    _adapter.cancelFunctionCalls(itemIds: itemIds, callIds: callIds);
  }

  // ---------------------------------------------------------------------------
  // Response control
  // ---------------------------------------------------------------------------

  /// Interrupt the model's current response.
  Future<void> interrupt() {
    logger.info('Interrupting current response');
    return _adapter.interrupt();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    logger.info('Disposing RealtimeService');
    await unbindAudioInput();
    await _adapter.dispose();
    await super.dispose();
    logger.info('RealtimeService disposed successfully');
  }

  // ---------------------------------------------------------------------------
  // Adapter factory
  // ---------------------------------------------------------------------------

  RealtimeAdapter _createAdapter(VoiceAgentApiConfig apiConfig) {
    logger.fine(
        'Creating realtime adapter for config type: ${apiConfig.runtimeType}');
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
