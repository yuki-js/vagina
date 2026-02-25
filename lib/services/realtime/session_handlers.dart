import 'package:vagina/services/log_service.dart';
import 'realtime_types.dart';
import 'realtime_streams.dart';

/// Handles session, conversation, and input audio events
///
/// Events:
/// - session.created, session.updated, transcription_session.updated
/// - conversation.created, conversation.item.*
/// - conversation.item.input_audio_transcription.*
/// - input_audio_buffer.*
class SessionHandlers {
  static const _tag = 'RealtimeAPI.Session';

  final RealtimeStreams _streams;
  final LogService _log;
  final void Function() _onSessionCreated;

  SessionHandlers({
    required RealtimeStreams streams,
    required LogService log,
    required void Function() onSessionCreated,
  })  : _streams = streams,
        _log = log,
        _onSessionCreated = onSessionCreated;

  // =============================================================================
  // Session Event Handlers
  // =============================================================================

  /// Handle session.created event
  /// Emitted automatically when a new connection is established as the first server event.
  void handleSessionCreated(Map<String, dynamic> message, String eventId) {
    _log.info(_tag, 'Session created, sending session.update');

    final sessionJson = message['session'] as Map<String, dynamic>?;
    if (sessionJson != null) {
      final session = RealtimeSession.fromJson(sessionJson);
      _streams.emitSessionCreated(session);
      _log.debug(_tag, 'Session ID: ${session.id}, Model: ${session.model}');
    }

    // Send session.update after session is created
    _onSessionCreated();
  }

  /// Handle session.updated event
  /// Returned when a session is updated with a session.update event.
  void handleSessionUpdated(Map<String, dynamic> message, String eventId) {
    final sessionJson = message['session'] as Map<String, dynamic>?;
    if (sessionJson != null) {
      final session = RealtimeSession.fromJson(sessionJson);
      _streams.emitSessionUpdated(session);

      final turnDetection =
          sessionJson['turn_detection'] as Map<String, dynamic>?;
      final transcription =
          sessionJson['input_audio_transcription'] as Map<String, dynamic>?;
      final tools = sessionJson['tools'] as List?;
      _log.info(
        _tag,
        'Session updated - turn_detection: ${turnDetection?['type']}, '
        'transcription: ${transcription?['model']}, tools: ${tools?.length ?? 0}',
      );
    } else {
      _log.info(_tag, 'Session updated');
    }
  }

  /// Handle transcription_session.updated event
  /// Returned when a transcription session is updated.
  void handleTranscriptionSessionUpdated(
      Map<String, dynamic> message, String eventId) {
    _log.info(_tag, 'Transcription session updated');
    // This is for transcription-only sessions, which we don't currently use
    // but we handle it for completeness
  }

  // =============================================================================
  // Conversation Event Handlers
  // =============================================================================

  /// Handle conversation.created event
  /// Returned when a conversation is created, emitted right after session creation.
  void handleConversationCreated(Map<String, dynamic> message, String eventId) {
    final conversationJson = message['conversation'] as Map<String, dynamic>?;
    if (conversationJson != null) {
      final conversation = RealtimeConversation.fromJson(conversationJson);
      _streams.emitConversationCreated(conversation);
      _log.info(_tag, 'Conversation created: ${conversation.id}');
    } else {
      _log.info(_tag, 'Conversation created');
    }
  }

  /// Handle conversation.item.created event
  /// Returned when a conversation item is created.
  void handleConversationItemCreated(
      Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    final previousItemId = message['previous_item_id'] as String?;

    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _streams.emitConversationItemCreated(item);
      _log.debug(
        _tag,
        'Conversation item created: ${item.id} (type: ${item.type}, '
        'role: ${item.role}, previous: $previousItemId)',
      );
    }
  }

  /// Handle conversation.item.deleted event
  /// Returned when an item in the conversation is deleted.
  void handleConversationItemDeleted(
      Map<String, dynamic> message, String eventId) {
    final itemId = message['item_id'] as String?;
    if (itemId != null) {
      _streams.emitConversationItemDeleted(itemId);
      _log.info(_tag, 'Conversation item deleted: $itemId');
    }
  }

  /// Handle conversation.item.truncated event
  /// Returned when an earlier assistant audio message item is truncated.
  void handleConversationItemTruncated(
      Map<String, dynamic> message, String eventId) {
    final itemId = message['item_id'] as String?;
    final contentIndex = message['content_index'] as int?;
    final audioEndMs = message['audio_end_ms'] as int?;
    _log.info(
      _tag,
      'Conversation item truncated: $itemId '
      '(content_index: $contentIndex, audio_end_ms: $audioEndMs)',
    );
  }

  /// Handle conversation.item.retrieved event
  /// Returned when a conversation item is retrieved.
  void handleConversationItemRetrieved(
      Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _log.info(_tag, 'Conversation item retrieved: ${item.id}');
    }
  }

  // =============================================================================
  // Input Audio Transcription Event Handlers
  // =============================================================================

  /// Handle conversation.item.input_audio_transcription.completed event
  /// User's speech transcription is done.
  void handleInputAudioTranscriptionCompleted(
      Map<String, dynamic> message, String eventId) {
    final transcript = message['transcript'] as String?;
    final itemId = message['item_id'] as String?;

    if (transcript != null && transcript.isNotEmpty) {
      _log.info(_tag, 'User transcript completed: $transcript');
      _streams.emitUserTranscript(transcript);
    } else {
      _log.warn(_tag, 'User transcript received but empty (item_id: $itemId)');
    }
  }

  /// Handle conversation.item.input_audio_transcription.delta event
  /// Streaming transcription updates for user audio.
  void handleInputAudioTranscriptionDelta(
      Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;

    if (delta != null && delta.isNotEmpty) {
      _log.debug(_tag, 'User transcript delta: $delta');
      _streams.emitUserTranscriptDelta(delta);
    }
  }

  /// Handle conversation.item.input_audio_transcription.failed event
  /// Transcription request failed.
  void handleInputAudioTranscriptionFailed(
      Map<String, dynamic> message, String eventId) {
    final errorJson = message['error'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;

    if (errorJson != null) {
      final error = RealtimeError.fromJson(errorJson);
      _log.error(
        _tag,
        'User transcription failed (item_id: $itemId): '
        '[${error.code}] ${error.message}',
      );
    } else {
      _log.error(
          _tag, 'User transcription failed (item_id: $itemId): unknown error');
    }
  }

  // =============================================================================
  // Input Audio Buffer Event Handlers
  // =============================================================================

  /// Handle input_audio_buffer.committed event
  /// Audio buffer was committed.
  void handleInputAudioBufferCommitted(
      Map<String, dynamic> message, String eventId) {
    final previousItemId = message['previous_item_id'] as String?;
    final itemId = message['item_id'] as String?;
    _log.info(_tag,
        'Audio buffer committed (item_id: $itemId, previous: $previousItemId)');
  }

  /// Handle input_audio_buffer.cleared event
  /// Audio buffer was cleared.
  void handleInputAudioBufferCleared(
      Map<String, dynamic> message, String eventId) {
    _log.info(_tag, 'Audio buffer cleared');
  }

  /// Handle input_audio_buffer.speech_started event
  /// VAD detected speech in the audio buffer.
  void handleInputAudioBufferSpeechStarted(
      Map<String, dynamic> message, String eventId) {
    final audioStartMs = message['audio_start_ms'] as int?;
    final itemId = message['item_id'] as String?;

    _log.info(_tag,
        'Speech started (VAD detected) at ${audioStartMs}ms, item_id: $itemId');

    // Notify that user speech started (for creating placeholder message)
    _streams.emitSpeechStarted();
    // Stop current audio playback when user starts speaking (interrupt)
    _streams.emitResponseStarted();
  }

  /// Handle input_audio_buffer.speech_stopped event
  /// VAD detected end of speech.
  void handleInputAudioBufferSpeechStopped(
      Map<String, dynamic> message, String eventId) {
    final audioEndMs = message['audio_end_ms'] as int?;
    final itemId = message['item_id'] as String?;
    _log.info(_tag,
        'Speech stopped (VAD detected) at ${audioEndMs}ms, item_id: $itemId');
  }
}
