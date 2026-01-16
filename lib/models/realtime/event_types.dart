/// Event type enumerations for Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime
library;

/// Events sent by the client to the Azure OpenAI Realtime API
/// Total: 12 client events
enum ClientEventType {
  /// Update the session configuration
  sessionUpdate('session.update'),

  /// Append audio data to the input audio buffer
  inputAudioBufferAppend('input_audio_buffer.append'),

  /// Commit the input audio buffer (used when VAD is disabled)
  inputAudioBufferCommit('input_audio_buffer.commit'),

  /// Clear the input audio buffer
  inputAudioBufferClear('input_audio_buffer.clear'),

  /// Clear the output audio buffer (WebRTC only)
  outputAudioBufferClear('output_audio_buffer.clear'),

  /// Create a new conversation item
  conversationItemCreate('conversation.item.create'),

  /// Truncate a conversation item (audio)
  conversationItemTruncate('conversation.item.truncate'),

  /// Delete a conversation item
  conversationItemDelete('conversation.item.delete'),

  /// Retrieve a conversation item
  conversationItemRetrieve('conversation.item.retrieve'),

  /// Create a new response
  responseCreate('response.create'),

  /// Cancel the current response
  responseCancel('response.cancel'),

  /// Update transcription session configuration
  transcriptionSessionUpdate('transcription_session.update');

  final String value;
  const ClientEventType(this.value);
}

/// Events received from the Azure OpenAI Realtime API
/// Total: 36 server events
enum ServerEventType {
  // ===== Error Events =====
  error('error'),

  // ===== Session Events =====
  sessionCreated('session.created'),
  sessionUpdated('session.updated'),
  transcriptionSessionUpdated('transcription_session.updated'),

  // ===== Conversation Events =====
  conversationCreated('conversation.created'),
  conversationItemCreated('conversation.item.created'),
  conversationItemDeleted('conversation.item.deleted'),
  conversationItemTruncated('conversation.item.truncated'),
  conversationItemRetrieved('conversation.item.retrieved'),

  // ===== Input Audio Transcription Events =====
  conversationItemInputAudioTranscriptionCompleted(
      'conversation.item.input_audio_transcription.completed'),
  conversationItemInputAudioTranscriptionDelta(
      'conversation.item.input_audio_transcription.delta'),
  conversationItemInputAudioTranscriptionFailed(
      'conversation.item.input_audio_transcription.failed'),

  // ===== Input Audio Buffer Events =====
  inputAudioBufferCommitted('input_audio_buffer.committed'),
  inputAudioBufferCleared('input_audio_buffer.cleared'),
  inputAudioBufferSpeechStarted('input_audio_buffer.speech_started'),
  inputAudioBufferSpeechStopped('input_audio_buffer.speech_stopped'),

  // ===== Output Audio Buffer Events (WebRTC only) =====
  outputAudioBufferStarted('output_audio_buffer.started'),
  outputAudioBufferStopped('output_audio_buffer.stopped'),
  outputAudioBufferCleared('output_audio_buffer.cleared'),

  // ===== Response Events =====
  responseCreated('response.created'),
  responseDone('response.done'),

  // ===== Response Output Item Events =====
  responseOutputItemAdded('response.output_item.added'),
  responseOutputItemDone('response.output_item.done'),

  // ===== Response Content Part Events =====
  responseContentPartAdded('response.content_part.added'),
  responseContentPartDone('response.content_part.done'),

  // ===== Response Text Events =====
  responseTextDelta('response.text.delta'),
  responseTextDone('response.text.done'),

  // ===== Response Audio Transcript Events =====
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  responseAudioTranscriptDone('response.audio_transcript.done'),

  // ===== Response Audio Events =====
  responseAudioDelta('response.audio.delta'),
  responseAudioDone('response.audio.done'),

  // ===== Response Function Call Events =====
  responseFunctionCallArgumentsDelta('response.function_call_arguments.delta'),
  responseFunctionCallArgumentsDone('response.function_call_arguments.done'),

  // ===== Rate Limits Events =====
  rateLimitsUpdated('rate_limits.updated');

  final String value;
  const ServerEventType(this.value);

  /// Static map for O(1) lookup
  static final Map<String, ServerEventType> _valueMap = {
    for (final type in ServerEventType.values) type.value: type
  };

  /// Get ServerEventType from string value (O(1) lookup)
  static ServerEventType? fromString(String value) => _valueMap[value];
}
