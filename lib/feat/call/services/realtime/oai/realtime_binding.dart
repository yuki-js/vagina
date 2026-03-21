import 'dart:async';
import 'dart:typed_data';

import 'realtime_command.dart';
import 'realtime_command_encoder.dart';
import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_event.dart';
import 'realtime_event_parser.dart';
import 'realtime_transport.dart';
import 'websocket_realtime_transport.dart';

/// Thin OpenAI Realtime binding.
///
/// Responsibilities:
/// - connect and disconnect the websocket transport
/// - parse inbound protocol payloads into typed OAI events
/// - expose one Dart stream per concrete non-MCP event
/// - encode and send outbound protocol commands
///
/// Non-responsibilities:
/// - business logic
/// - accumulation or projection
/// - provider-agnostic mapping
final class OaiRealtimeClient {
  final OaiRealtimeTransport _transport;
  final OaiRealtimeEventParser _parser;
  final OaiRealtimeCommandEncoder _encoder;

  final StreamController<OaiRealtimeInboundEvent> _eventController =
      StreamController<OaiRealtimeInboundEvent>.broadcast();
  final StreamController<OaiRealtimeConnectionError> _errorController =
      StreamController<OaiRealtimeConnectionError>.broadcast();

  late final StreamSubscription<Map<String, dynamic>> _messageSubscription;
  late final StreamSubscription<OaiRealtimeConnectionState>
      _connectionStateSubscription;

  bool _disposed = false;

  OaiRealtimeClient({
    OaiRealtimeTransport? transport,
    OaiRealtimeEventParser? parser,
    OaiRealtimeCommandEncoder? encoder,
  })  : _transport = transport ?? WebSocketOaiRealtimeTransport(),
        _parser = parser ?? const OaiRealtimeEventParser(),
        _encoder = encoder ?? const OaiRealtimeCommandEncoder() {
    _messageSubscription = _transport.inboundMessages.listen(_handleInbound);
    _connectionStateSubscription =
        _transport.connectionStates.listen(_handleConnectionState);
  }

  bool get isConnected => _transport.isConnected;

  Stream<OaiRealtimeConnectionState> get connectionStates =>
      _transport.connectionStates;

  Stream<OaiRealtimeConnectionError> get connectionErrors =>
      _errorController.stream;

  Stream<OaiRealtimeSessionCreatedEvent> get sessionCreatedEvents =>
      _typedStream<OaiRealtimeSessionCreatedEvent>();

  Stream<OaiRealtimeSessionUpdatedEvent> get sessionUpdatedEvents =>
      _typedStream<OaiRealtimeSessionUpdatedEvent>();

  Stream<OaiRealtimeTranscriptionSessionUpdatedEvent>
      get transcriptionSessionUpdatedEvents =>
          _typedStream<OaiRealtimeTranscriptionSessionUpdatedEvent>();

  Stream<OaiRealtimeConversationCreatedEvent> get conversationCreatedEvents =>
      _typedStream<OaiRealtimeConversationCreatedEvent>();

  Stream<OaiRealtimeConversationItemCreatedEvent>
      get conversationItemCreatedEvents =>
          _typedStream<OaiRealtimeConversationItemCreatedEvent>();

  Stream<OaiRealtimeConversationItemDeletedEvent>
      get conversationItemDeletedEvents =>
          _typedStream<OaiRealtimeConversationItemDeletedEvent>();

  Stream<OaiRealtimeConversationItemInputAudioTranscriptionCompletedEvent>
      get conversationItemInputAudioTranscriptionCompletedEvents => _typedStream<
          OaiRealtimeConversationItemInputAudioTranscriptionCompletedEvent>();

  Stream<OaiRealtimeConversationItemInputAudioTranscriptionDeltaEvent>
      get conversationItemInputAudioTranscriptionDeltaEvents => _typedStream<
          OaiRealtimeConversationItemInputAudioTranscriptionDeltaEvent>();

  Stream<OaiRealtimeConversationItemInputAudioTranscriptionFailedEvent>
      get conversationItemInputAudioTranscriptionFailedEvents => _typedStream<
          OaiRealtimeConversationItemInputAudioTranscriptionFailedEvent>();

  Stream<OaiRealtimeConversationItemTruncatedEvent>
      get conversationItemTruncatedEvents =>
          _typedStream<OaiRealtimeConversationItemTruncatedEvent>();

  Stream<OaiRealtimeInputAudioBufferCommittedEvent>
      get inputAudioBufferCommittedEvents =>
          _typedStream<OaiRealtimeInputAudioBufferCommittedEvent>();

  Stream<OaiRealtimeInputAudioBufferClearedEvent>
      get inputAudioBufferClearedEvents =>
          _typedStream<OaiRealtimeInputAudioBufferClearedEvent>();

  Stream<OaiRealtimeInputAudioBufferDtmfEventReceivedEvent>
      get inputAudioBufferDtmfEventReceivedEvents =>
          _typedStream<OaiRealtimeInputAudioBufferDtmfEventReceivedEvent>();

  Stream<OaiRealtimeInputAudioBufferSpeechStartedEvent>
      get inputAudioBufferSpeechStartedEvents =>
          _typedStream<OaiRealtimeInputAudioBufferSpeechStartedEvent>();

  Stream<OaiRealtimeInputAudioBufferSpeechStoppedEvent>
      get inputAudioBufferSpeechStoppedEvents =>
          _typedStream<OaiRealtimeInputAudioBufferSpeechStoppedEvent>();

  Stream<OaiRealtimeResponseCreatedEvent> get responseCreatedEvents =>
      _typedStream<OaiRealtimeResponseCreatedEvent>();

  Stream<OaiRealtimeResponseDoneEvent> get responseDoneEvents =>
      _typedStream<OaiRealtimeResponseDoneEvent>();

  Stream<OaiRealtimeResponseOutputItemAddedEvent>
      get responseOutputItemAddedEvents =>
          _typedStream<OaiRealtimeResponseOutputItemAddedEvent>();

  Stream<OaiRealtimeResponseOutputItemDoneEvent>
      get responseOutputItemDoneEvents =>
          _typedStream<OaiRealtimeResponseOutputItemDoneEvent>();

  Stream<OaiRealtimeResponseContentPartAddedEvent>
      get responseContentPartAddedEvents =>
          _typedStream<OaiRealtimeResponseContentPartAddedEvent>();

  Stream<OaiRealtimeResponseContentPartDoneEvent>
      get responseContentPartDoneEvents =>
          _typedStream<OaiRealtimeResponseContentPartDoneEvent>();

  Stream<OaiRealtimeResponseOutputTextDeltaEvent>
      get responseOutputTextDeltaEvents =>
          _typedStream<OaiRealtimeResponseOutputTextDeltaEvent>();

  Stream<OaiRealtimeResponseOutputTextDoneEvent>
      get responseOutputTextDoneEvents =>
          _typedStream<OaiRealtimeResponseOutputTextDoneEvent>();

  Stream<OaiRealtimeResponseOutputAudioDeltaEvent>
      get responseOutputAudioDeltaEvents =>
          _typedStream<OaiRealtimeResponseOutputAudioDeltaEvent>();

  Stream<OaiRealtimeResponseOutputAudioDoneEvent>
      get responseOutputAudioDoneEvents =>
          _typedStream<OaiRealtimeResponseOutputAudioDoneEvent>();

  Stream<OaiRealtimeResponseOutputAudioTranscriptDeltaEvent>
      get responseOutputAudioTranscriptDeltaEvents =>
          _typedStream<OaiRealtimeResponseOutputAudioTranscriptDeltaEvent>();

  Stream<OaiRealtimeResponseOutputAudioTranscriptDoneEvent>
      get responseOutputAudioTranscriptDoneEvents =>
          _typedStream<OaiRealtimeResponseOutputAudioTranscriptDoneEvent>();

  Stream<OaiRealtimeResponseFunctionCallArgumentsDeltaEvent>
      get responseFunctionCallArgumentsDeltaEvents =>
          _typedStream<OaiRealtimeResponseFunctionCallArgumentsDeltaEvent>();

  Stream<OaiRealtimeResponseFunctionCallArgumentsDoneEvent>
      get responseFunctionCallArgumentsDoneEvents =>
          _typedStream<OaiRealtimeResponseFunctionCallArgumentsDoneEvent>();

  Stream<OaiRealtimeRateLimitsUpdatedEvent> get rateLimitsUpdatedEvents =>
      _typedStream<OaiRealtimeRateLimitsUpdatedEvent>();

  Stream<OaiRealtimeErrorEvent> get errorEvents =>
      _typedStream<OaiRealtimeErrorEvent>();

  Future<void> connect(OaiRealtimeConnectConfig config) {
    _ensureNotDisposed();
    return _transport.connect(config);
  }

  Future<void> disconnect() {
    _ensureNotDisposed();
    return _transport.disconnect();
  }

  Future<void> updateSession(Map<String, dynamic> session) {
    return _send(OaiSessionUpdateCommand(session: session));
  }

  Future<void> updateTranscriptionSession(Map<String, dynamic> session) {
    return _send(OaiTranscriptionSessionUpdateCommand(session: session));
  }

  Future<void> appendInputAudio(Uint8List audioBytes) {
    return _send(OaiInputAudioBufferAppendCommand(audioBytes: audioBytes));
  }

  Future<void> commitInputAudioBuffer() {
    return _send(const OaiInputAudioBufferCommitCommand());
  }

  Future<void> clearInputAudioBuffer() {
    return _send(const OaiInputAudioBufferClearCommand());
  }

  Future<void> clearOutputAudioBuffer() {
    return _send(const OaiOutputAudioBufferClearCommand());
  }

  Future<void> createConversationItem({
    String? previousItemId,
    required Map<String, dynamic> item,
  }) {
    return _send(
      OaiConversationItemCreateCommand(
        previousItemId: previousItemId,
        item: item,
      ),
    );
  }

  Future<void> deleteConversationItem(String itemId) {
    return _send(OaiConversationItemDeleteCommand(itemId: itemId));
  }

  Future<void> retrieveConversationItem(String itemId) {
    return _send(OaiConversationItemRetrieveCommand(itemId: itemId));
  }

  Future<void> truncateConversationItem({
    required String itemId,
    required int contentIndex,
    required int audioEndMs,
  }) {
    return _send(
      OaiConversationItemTruncateCommand(
        itemId: itemId,
        contentIndex: contentIndex,
        audioEndMs: audioEndMs,
      ),
    );
  }

  Future<void> createResponse({Map<String, dynamic>? response}) {
    return _send(OaiResponseCreateCommand(response: response));
  }

  Future<void> cancelResponse() {
    return _send(const OaiResponseCancelCommand());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _messageSubscription.cancel();
    await _connectionStateSubscription.cancel();
    await _transport.dispose();
    await _eventController.close();
    await _errorController.close();
  }

  Future<void> _send(OaiRealtimeCommand command) async {
    _ensureNotDisposed();
    final payload = _encoder.encode(command);
    await _transport.sendJson(payload);
  }

  void _handleInbound(Map<String, dynamic> payload) {
    try {
      final event = _parser.parse(payload);
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    } on OaiRealtimeProtocolException catch (error) {
      _emitConnectionError(error.toConnectionError());
    } catch (error) {
      _emitConnectionError(
        OaiRealtimeConnectionError(
          code: 'unexpected_parse_error',
          message: 'Unexpected realtime parse error.',
          cause: error,
        ),
      );
    }
  }

  void _handleConnectionState(OaiRealtimeConnectionState state) {
    if (state.phase == OaiRealtimeConnectionPhase.failed) {
      _emitConnectionError(
        OaiRealtimeConnectionError(
          code: 'transport_failed',
          message: state.message ?? 'Realtime transport failed.',
          cause: state.error,
        ),
      );
    }
  }

  void _emitConnectionError(OaiRealtimeConnectionError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  Stream<T> _typedStream<T extends OaiRealtimeInboundEvent>() {
    return _eventController.stream.where((event) => event is T).cast<T>();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('OaiRealtimeClient is already disposed.');
    }
  }
}
