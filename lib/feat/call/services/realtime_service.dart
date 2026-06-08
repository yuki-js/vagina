import 'dart:async';
import 'dart:typed_data';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/services/subservice.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'realtime/realtime_adapter.dart';
import 'realtime/realtime_adapter_factory.dart';

/// Session-scoped realtime backing service for a single call.
final class RealtimeService extends SubService {
  final VoiceAgentInfo voiceAgent;
  late final RealtimeAdapter _adapter;
  final StreamController<bool> _userSpeakingProjectionController =
      StreamController<bool>.broadcast();
  StreamSubscription<bool>? _adapterUserSpeakingSubscription;
  bool _adapterUserSpeaking = false;
  bool _manualAudioTurnSpeaking = false;
  bool _isUserSpeakingProjection = false;

  RealtimeService({required this.voiceAgent}) {
    _adapter = _createAdapter(voiceAgent.apiConfig);
    _adapterUserSpeaking = _adapter.isUserSpeaking;
    _adapterUserSpeakingSubscription =
        _adapter.isUserSpeakingUpdates.listen((isSpeaking) {
      _adapterUserSpeaking = isSpeaking;
      _refreshUserSpeakingProjection();
    });
  }

  RealtimeThread get thread => _adapter.thread;

  Stream<RealtimeThread> get threadUpdates => _adapter.threadUpdates;

  RealtimeAdapterConnectionState get connectionState => _adapter.connectionState;

  Stream<RealtimeAdapterConnectionState> get connectionStateUpdates =>
      _adapter.connectionStateUpdates;

  Stream<RealtimeAdapterError> get errors => _adapter.errors;

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

  // ---------------------------------------------------------------------------
  // Audio input / output
  // ---------------------------------------------------------------------------

  /// Bind or unbind a live PCM audio stream to the realtime adapter.
  Future<void> bindAudioInput(Stream<Uint8List>? audioStream) {
    logger.info(audioStream == null
        ? 'Unbinding audio input stream from realtime adapter'
        : 'Binding audio input stream to realtime adapter');
    return _adapter.bindAudioInput(audioStream);
  }

  Future<void> setAudioTurnMode(RealtimeAudioTurnMode mode) {
    logger.info('Setting audio turn mode to: $mode');
    return _adapter.setAudioTurnMode(mode);
  }

  void projectManualAudioTurnSpeakingState(bool isSpeaking) {
    logger.fine('Projecting manual audio turn speaking state: $isSpeaking');
    _manualAudioTurnSpeaking = isSpeaking;
    _refreshUserSpeakingProjection();
  }

  /// Provider-decoded assistant PCM output stream.
  Stream<Uint8List> get assistantAudioStream => _adapter.assistantAudioStream;

  /// Completion signal for the current assistant audio response.
  Stream<void> get assistantAudioCompleted => _adapter.assistantAudioCompleted;

  /// Whether the user is currently considered to be speaking.
  bool get isUserSpeaking => _isUserSpeakingProjection;

  /// Emits the projected user speaking state whenever it changes.
  Stream<bool> get isUserSpeakingUpdates =>
      _userSpeakingProjectionController.stream;

  // ---------------------------------------------------------------------------
  // Tool configuration
  // ---------------------------------------------------------------------------

  Future<void> registerTools(List<ToolDefinition> tools) {
    logger.info('Registering ${tools.length} tools with realtime adapter');
    logger.fine('Tool names: ${tools.map((t) => t.toolKey).join(", ")}');
    return _adapter.registerTools(tools);
  }

  Future<void> setInstructions(String? instructions) {
    logger.info('Updating realtime instructions');
    return _adapter.setInstructions(instructions);
  }

  Future<bool> applyProviderExtension(
    String extensionType,
    Map<String, dynamic> payload,
  ) {
    logger.info('Applying realtime provider extension: $extensionType');
    return _adapter.applyProviderExtension(extensionType, payload);
  }

  // ---------------------------------------------------------------------------
  // User content
  // ---------------------------------------------------------------------------

  Future<String> sendAudioOneShot(Uint8List audioBytes) {
    logger.info('Sending completed manual audio turn (${audioBytes.length} bytes)');
    return _adapter.sendAudioOneShot(audioBytes);
  }

  Future<String> sendText(String text) {
    logger.info('Sending text message (${text.length} chars)');
    logger.fine(
        'Text content: ${text.length > 100 ? "${text.substring(0, 100)}..." : text}');
    return _adapter.sendText(text);
  }

  Future<String> sendImage(Uint8List imageBytes) {
    logger.info('Sending image (${imageBytes.length} bytes)');
    return _adapter.sendImage(imageBytes);
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
    await _adapterUserSpeakingSubscription?.cancel();
    _adapterUserSpeakingSubscription = null;
    await _adapter.dispose();
    await _userSpeakingProjectionController.close();
    await super.dispose();
    logger.info('RealtimeService disposed successfully');
  }

  void _refreshUserSpeakingProjection() {
    _setProjectedUserSpeaking(_adapterUserSpeaking || _manualAudioTurnSpeaking);
  }

  void _setProjectedUserSpeaking(bool value) {
    if (_isUserSpeakingProjection == value) {
      return;
    }
    _isUserSpeakingProjection = value;
    if (!_userSpeakingProjectionController.isClosed) {
      _userSpeakingProjectionController.add(value);
    }
  }

  // ---------------------------------------------------------------------------
  // Adapter factory
  // ---------------------------------------------------------------------------

  RealtimeAdapter _createAdapter(VoiceAgentApiConfig apiConfig) {
    logger.fine(
        'Creating realtime adapter for config type: ${apiConfig.runtimeType}');
    return RealtimeAdapterFactory.create(apiConfig);
  }
}
