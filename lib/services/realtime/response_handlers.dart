import 'dart:convert';
import 'dart:typed_data';

import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/services/log_service.dart';
import 'realtime_types.dart';
import 'realtime_streams.dart';
import 'realtime_state.dart';

/// Handles response, function call, and misc events
///
/// Events:
/// - response.*, response.output_item.*, response.content_part.*
/// - response.text.*, response.audio_transcript.*, response.audio.*
/// - response.function_call_arguments.*
/// - output_audio_buffer.* (WebRTC only)
/// - rate_limits.updated, error
class ResponseHandlers {
  static const _tag = 'RealtimeAPI.Response';

  final RealtimeStreams _streams;
  final LogService _log;
  final RealtimeState _state;

  ResponseHandlers({
    required RealtimeStreams streams,
    required LogService log,
    required RealtimeState state,
  })  : _streams = streams,
        _log = log,
        _state = state;

  // =============================================================================
  // Response Event Handlers
  // =============================================================================

  /// Handle response.created event
  /// New response is being generated.
  void handleResponseCreated(Map<String, dynamic> message, String eventId) {
    final responseJson = message['response'] as Map<String, dynamic>?;

    _log.info(_tag, 'Response created - AI is generating response');
    _state.audioChunksReceived =
        0; // Reset audio chunk counter for new response

    if (responseJson != null) {
      final response = RealtimeResponse.fromJson(responseJson);
      _log.debug(
          _tag, 'Response ID: ${response.id}, Status: ${response.status}');
    }
    // Don't stop audio here - let it play until speech_started interrupts
  }

  /// Handle response.done event
  /// Response generation is complete.
  void handleResponseDone(Map<String, dynamic> message, String eventId) {
    final responseJson = message['response'] as Map<String, dynamic>?;

    if (responseJson != null) {
      final response = RealtimeResponse.fromJson(responseJson);
      _streams.emitResponseDone(response);

      final usage = response.usage;
      if (usage != null) {
        _log.info(
          _tag,
          'Response complete - Status: ${response.status}, '
          'Tokens: ${usage.totalTokens} (in: ${usage.inputTokens}, out: ${usage.outputTokens})',
        );
      } else {
        _log.info(_tag, 'Response complete - Status: ${response.status}');
      }
    } else {
      _log.info(_tag, 'Response complete');
    }
  }

  // =============================================================================
  // Response Output Item Event Handlers
  // =============================================================================

  /// Handle response.output_item.added event
  /// New item added during response generation.
  void handleResponseOutputItemAdded(
      Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final outputIndex = message['output_index'] as int?;

    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);

      // Check if this is a function call
      if (item.type == 'function_call') {
        final callId = item.callId ?? '';
        final name = item.name ?? '';
        _state.pendingFunctionCalls[callId] = StringBuffer();
        _state.pendingFunctionNames[callId] = name;
        _log.info(_tag, 'Function call started: $name (call_id: $callId)');
      } else {
        _log.debug(
          _tag,
          'Output item added: ${item.id} (type: ${item.type}, '
          'response_id: $responseId, index: $outputIndex)',
        );
      }
    }
  }

  /// Handle response.output_item.done event
  /// Item streaming is complete.
  void handleResponseOutputItemDone(
      Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;

    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _log.debug(_tag, 'Output item done: ${item.id} (status: ${item.status})');
    }
  }

  // =============================================================================
  // Response Content Part Event Handlers
  // =============================================================================

  /// Handle response.content_part.added event
  /// New content part added to an item.
  void handleResponseContentPartAdded(
      Map<String, dynamic> message, String eventId) {
    final partJson = message['part'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;
    final contentIndex = message['content_index'] as int?;

    if (partJson != null) {
      final partType = partJson['type'] as String?;
      _log.debug(_tag,
          'Content part added: $partType (item_id: $itemId, index: $contentIndex)');
    }
  }

  /// Handle response.content_part.done event
  /// Content part streaming is complete.
  void handleResponseContentPartDone(
      Map<String, dynamic> message, String eventId) {
    final partJson = message['part'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;

    if (partJson != null) {
      final partType = partJson['type'] as String?;
      _log.debug(_tag, 'Content part done: $partType (item_id: $itemId)');
    }
  }

  // =============================================================================
  // Response Text Event Handlers
  // =============================================================================

  /// Handle response.text.delta event
  /// Streaming text content update.
  void handleResponseTextDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;

    if (delta != null) {
      _streams.emitTextDelta(delta);
      // Also add to transcript stream for text-only responses
      _streams.emitTranscript(delta);
    }
  }

  /// Handle response.text.done event
  /// Text content streaming is complete.
  void handleResponseTextDone(Map<String, dynamic> message, String eventId) {
    final text = message['text'] as String?;
    final itemId = message['item_id'] as String?;

    if (text != null) {
      _streams.emitTextDone(text);
      _log.debug(_tag,
          'Text response complete (item_id: $itemId): ${text.length} chars');
    }
  }

  // =============================================================================
  // Response Audio Transcript Event Handlers
  // =============================================================================

  /// Handle response.audio_transcript.delta event
  /// Streaming audio transcription update.
  void handleResponseAudioTranscriptDelta(
      Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;

    if (delta != null) {
      // Don't log transcript deltas to reduce noise; they will appear in chat UI
      _streams.emitTranscript(delta);
    }
  }

  /// Handle response.audio_transcript.done event
  /// Audio transcription is complete.
  void handleResponseAudioTranscriptDone(
      Map<String, dynamic> message, String eventId) {
    final transcript = message['transcript'] as String?;
    final itemId = message['item_id'] as String?;

    _log.debug(
      _tag,
      'Audio transcript complete (item_id: $itemId): '
      '${transcript?.length ?? 0} chars',
    );
  }

  // =============================================================================
  // Response Audio Event Handlers
  // =============================================================================

  /// Handle response.audio.delta event
  /// Streaming audio data.
  void handleResponseAudioDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;

    if (delta != null) {
      _state.audioChunksReceived++;
      final audioData = base64Decode(delta);

      // Emit event when first audio chunk of a response arrives
      if (_state.audioChunksReceived == 1) {
        _streams.emitResponseAudioStarted();
        _log.info(_tag, 'AI audio response started (first chunk received)');
      }

      // Only log periodically to reduce log noise
      if (_state.audioChunksReceived % AppConfig.logAudioChunkInterval == 0) {
        _log.debug(
          _tag,
          'Audio delta received (chunk #${_state.audioChunksReceived}, '
          '${audioData.length} bytes)',
        );
      }

      _streams.emitAudio(Uint8List.fromList(audioData));
    }
  }

  /// Handle response.audio.done event
  /// Audio streaming is complete.
  void handleResponseAudioDone(Map<String, dynamic> message, String eventId) {
    _log.info(_tag,
        'Audio response complete. Total chunks received: ${_state.audioChunksReceived}');
    _streams.emitAudioDone();
  }

  // =============================================================================
  // Response Function Call Event Handlers
  // =============================================================================

  /// Handle response.function_call_arguments.delta event
  /// Streaming function call arguments.
  void handleFunctionCallArgumentsDelta(
      Map<String, dynamic> message, String eventId) {
    final callId = message['call_id'] as String?;
    final delta = message['delta'] as String?;

    if (callId != null && delta != null) {
      _state.pendingFunctionCalls[callId]?.write(delta);
      _log.debug(_tag, 'Function call arguments delta: $delta');
    }
  }

  /// Handle response.function_call_arguments.done event
  /// Function call arguments complete.
  void handleFunctionCallArgumentsDone(
      Map<String, dynamic> message, String eventId) {
    final callId = message['call_id'] as String?;

    if (callId != null && _state.pendingFunctionCalls.containsKey(callId)) {
      final arguments = _state.pendingFunctionCalls[callId]!.toString();
      final name = _state.pendingFunctionNames[callId] ?? 'unknown';

      _log.info(_tag, 'Function call complete: $name with args: $arguments');

      _streams.emitFunctionCall(FunctionCall(
        callId: callId,
        name: name,
        arguments: arguments,
      ));

      // Cleanup
      _state.pendingFunctionCalls.remove(callId);
      _state.pendingFunctionNames.remove(callId);
    }
  }

  // =============================================================================
  // Output Audio Buffer Event Handlers (WebRTC only)
  // =============================================================================

  /// Handle output_audio_buffer.started event
  /// Server began streaming audio (WebRTC only).
  void handleOutputAudioBufferStarted(
      Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _log.debug(_tag,
        'Output audio buffer started (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
    // We log it but take no action in our WebSocket-based implementation
  }

  /// Handle output_audio_buffer.stopped event
  /// Audio buffer drained (WebRTC only).
  void handleOutputAudioBufferStopped(
      Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _log.debug(_tag,
        'Output audio buffer stopped (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
  }

  /// Handle output_audio_buffer.cleared event
  /// Audio buffer was cleared (WebRTC only).
  void handleOutputAudioBufferCleared(
      Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _log.debug(_tag,
        'Output audio buffer cleared (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
  }

  // =============================================================================
  // Rate Limits Event Handlers
  // =============================================================================

  /// Handle rate_limits.updated event
  /// Emitted at the beginning of a response to indicate updated rate limits.
  void handleRateLimitsUpdated(Map<String, dynamic> message, String eventId) {
    final rateLimitsJson = message['rate_limits'] as List<dynamic>?;

    if (rateLimitsJson != null) {
      final rateLimits = rateLimitsJson
          .map((r) => RateLimit.fromJson(r as Map<String, dynamic>))
          .toList();

      _streams.emitRateLimitsUpdated(rateLimits);

      // Log rate limits for monitoring
      for (final limit in rateLimits) {
        _log.debug(
          _tag,
          'Rate limit ${limit.name}: ${limit.remaining}/${limit.limit} '
          '(resets in ${limit.resetSeconds.toStringAsFixed(1)}s)',
        );
      }
    }
  }

  // =============================================================================
  // Error Event Handler
  // =============================================================================

  /// Handle error event
  /// Returned when an error occurs.
  void handleError(Map<String, dynamic> message, String eventId) {
    final errorJson = message['error'] as Map<String, dynamic>?;

    if (errorJson != null) {
      final error = RealtimeError.fromJson(errorJson);
      final fullError = error.code != null
          ? '[${error.code}] ${error.message}'
          : error.message;

      _log.error(_tag, 'API error: $fullError');
      _state.lastError = fullError;
      _streams.emitError(fullError);
    } else {
      const unknownError = 'Unknown error';
      _log.error(_tag, 'API error: $unknownError');
      _state.lastError = unknownError;
      _streams.emitError(unknownError);
    }
  }
}
