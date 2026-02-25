import 'dart:async';
import 'dart:typed_data';
import 'realtime_types.dart';

/// Manages all 18 StreamControllers for the Realtime API
class RealtimeStreams {
  // Audio streams
  final _audioController = StreamController<Uint8List>.broadcast();
  final _audioDoneController = StreamController<void>.broadcast();
  final _responseAudioStartedController = StreamController<void>.broadcast();

  // Transcript streams
  final _transcriptController = StreamController<String>.broadcast();
  final _textDeltaController = StreamController<String>.broadcast();
  final _textDoneController = StreamController<String>.broadcast();

  // User input streams
  final _userTranscriptController = StreamController<String>.broadcast();
  final _userTranscriptDeltaController = StreamController<String>.broadcast();
  final _speechStartedController = StreamController<void>.broadcast();
  final _responseStartedController = StreamController<void>.broadcast();

  // Session/conversation streams
  final _sessionCreatedController =
      StreamController<RealtimeSession>.broadcast();
  final _sessionUpdatedController =
      StreamController<RealtimeSession>.broadcast();
  final _conversationCreatedController =
      StreamController<RealtimeConversation>.broadcast();
  final _conversationItemCreatedController =
      StreamController<ConversationItem>.broadcast();
  final _conversationItemDeletedController =
      StreamController<String>.broadcast();

  // Response streams
  final _responseDoneController =
      StreamController<RealtimeResponse>.broadcast();
  final _functionCallController = StreamController<FunctionCall>.broadcast();
  final _rateLimitsUpdatedController =
      StreamController<List<RateLimit>>.broadcast();

  // Error stream
  final _errorController = StreamController<String>.broadcast();

  // ========== Public Stream Getters ==========

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<void> get audioDoneStream => _audioDoneController.stream;
  Stream<void> get responseAudioStartedStream =>
      _responseAudioStartedController.stream;

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get textDeltaStream => _textDeltaController.stream;
  Stream<String> get textDoneStream => _textDoneController.stream;

  Stream<String> get userTranscriptStream => _userTranscriptController.stream;
  Stream<String> get userTranscriptDeltaStream =>
      _userTranscriptDeltaController.stream;
  Stream<void> get speechStartedStream => _speechStartedController.stream;
  Stream<void> get responseStartedStream => _responseStartedController.stream;

  Stream<RealtimeSession> get sessionCreatedStream =>
      _sessionCreatedController.stream;
  Stream<RealtimeSession> get sessionUpdatedStream =>
      _sessionUpdatedController.stream;
  Stream<RealtimeConversation> get conversationCreatedStream =>
      _conversationCreatedController.stream;
  Stream<ConversationItem> get conversationItemCreatedStream =>
      _conversationItemCreatedController.stream;
  Stream<String> get conversationItemDeletedStream =>
      _conversationItemDeletedController.stream;

  Stream<RealtimeResponse> get responseDoneStream =>
      _responseDoneController.stream;
  Stream<FunctionCall> get functionCallStream => _functionCallController.stream;
  Stream<List<RateLimit>> get rateLimitsUpdatedStream =>
      _rateLimitsUpdatedController.stream;

  Stream<String> get errorStream => _errorController.stream;

  // ========== Emit Methods (for handlers) ==========

  void emitAudio(Uint8List data) => _audioController.add(data);
  void emitAudioDone() => _audioDoneController.add(null);
  void emitResponseAudioStarted() => _responseAudioStartedController.add(null);

  void emitTranscript(String text) => _transcriptController.add(text);
  void emitTextDelta(String text) => _textDeltaController.add(text);
  void emitTextDone(String text) => _textDoneController.add(text);

  void emitUserTranscript(String text) => _userTranscriptController.add(text);
  void emitUserTranscriptDelta(String delta) =>
      _userTranscriptDeltaController.add(delta);
  void emitSpeechStarted() => _speechStartedController.add(null);
  void emitResponseStarted() => _responseStartedController.add(null);

  void emitSessionCreated(RealtimeSession session) =>
      _sessionCreatedController.add(session);
  void emitSessionUpdated(RealtimeSession session) =>
      _sessionUpdatedController.add(session);
  void emitConversationCreated(RealtimeConversation conversation) =>
      _conversationCreatedController.add(conversation);
  void emitConversationItemCreated(ConversationItem item) =>
      _conversationItemCreatedController.add(item);
  void emitConversationItemDeleted(String id) =>
      _conversationItemDeletedController.add(id);

  void emitResponseDone(RealtimeResponse response) =>
      _responseDoneController.add(response);
  void emitFunctionCall(FunctionCall call) => _functionCallController.add(call);
  void emitRateLimitsUpdated(List<RateLimit> limits) =>
      _rateLimitsUpdatedController.add(limits);

  void emitError(String error) => _errorController.add(error);

  // ========== Lifecycle ==========

  Future<void> dispose() async {
    await Future.wait([
      _audioController.close(),
      _audioDoneController.close(),
      _responseAudioStartedController.close(),
      _transcriptController.close(),
      _textDeltaController.close(),
      _textDoneController.close(),
      _userTranscriptController.close(),
      _userTranscriptDeltaController.close(),
      _speechStartedController.close(),
      _responseStartedController.close(),
      _sessionCreatedController.close(),
      _sessionUpdatedController.close(),
      _conversationCreatedController.close(),
      _conversationItemCreatedController.close(),
      _conversationItemDeletedController.close(),
      _responseDoneController.close(),
      _functionCallController.close(),
      _rateLimitsUpdatedController.close(),
      _errorController.close(),
    ]);
  }
}
