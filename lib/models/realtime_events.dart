/// Events sent by the client to the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-client-events
enum ClientEventType {
  /// Update session configuration
  sessionUpdate('session.update'),
  
  /// Append audio data to the input buffer
  inputAudioBufferAppend('input_audio_buffer.append'),
  
  /// Commit the current input audio buffer
  inputAudioBufferCommit('input_audio_buffer.commit'),
  
  /// Clear the input audio buffer
  inputAudioBufferClear('input_audio_buffer.clear'),
  
  /// Clear the output audio buffer
  outputAudioBufferClear('output_audio_buffer.clear'),
  
  /// Create a new conversation item
  conversationItemCreate('conversation.item.create'),
  
  /// Retrieve a conversation item
  conversationItemRetrieve('conversation.item.retrieve'),
  
  /// Truncate a conversation item
  conversationItemTruncate('conversation.item.truncate'),
  
  /// Delete a conversation item
  conversationItemDelete('conversation.item.delete'),
  
  /// Create a new response
  responseCreate('response.create'),
  
  /// Cancel the current response
  responseCancel('response.cancel'),
  
  /// Update transcription session (optional)
  transcriptionSessionUpdate('transcription_session.update');

  final String value;
  const ClientEventType(this.value);
}

/// Events received from the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-server-events
/// 
/// Total: 34 server event types
enum ServerEventType {
  // === Error ===
  /// An error occurred
  error('error'),
  
  // === Session Events ===
  /// Session has been created
  sessionCreated('session.created'),
  /// Session configuration has been updated
  sessionUpdated('session.updated'),
  
  // === Conversation Events ===
  /// A conversation has been created
  conversationCreated('conversation.created'),
  /// A conversation item has been created
  conversationItemCreated('conversation.item.created'),
  /// A conversation item has been retrieved
  conversationItemRetrieved('conversation.item.retrieved'),
  /// A conversation item has been truncated
  conversationItemTruncated('conversation.item.truncated'),
  /// A conversation item has been deleted
  conversationItemDeleted('conversation.item.deleted'),
  /// User audio transcription completed
  conversationItemInputAudioTranscriptionCompleted('conversation.item.input_audio_transcription.completed'),
  /// User audio transcription delta (streaming)
  conversationItemInputAudioTranscriptionDelta('conversation.item.input_audio_transcription.delta'),
  /// User audio transcription failed
  conversationItemInputAudioTranscriptionFailed('conversation.item.input_audio_transcription.failed'),
  
  // === Input Audio Buffer Events ===
  /// Input audio buffer has been committed
  inputAudioBufferCommitted('input_audio_buffer.committed'),
  /// Input audio buffer has been cleared
  inputAudioBufferCleared('input_audio_buffer.cleared'),
  /// VAD detected speech start
  inputAudioBufferSpeechStarted('input_audio_buffer.speech_started'),
  /// VAD detected speech stop
  inputAudioBufferSpeechStopped('input_audio_buffer.speech_stopped'),
  
  // === Output Audio Buffer Events ===
  /// Output audio playback started
  outputAudioBufferStarted('output_audio_buffer.started'),
  /// Output audio playback stopped
  outputAudioBufferStopped('output_audio_buffer.stopped'),
  /// Output audio buffer cleared
  outputAudioBufferCleared('output_audio_buffer.cleared'),
  
  // === Response Events ===
  /// Response generation started
  responseCreated('response.created'),
  /// Response generation completed
  responseDone('response.done'),
  /// Response output item added
  responseOutputItemAdded('response.output_item.added'),
  /// Response output item completed
  responseOutputItemDone('response.output_item.done'),
  /// Response content part added
  responseContentPartAdded('response.content_part.added'),
  /// Response content part completed
  responseContentPartDone('response.content_part.done'),
  /// Response text delta (streaming)
  responseTextDelta('response.text.delta'),
  /// Response text completed
  responseTextDone('response.text.done'),
  /// Response audio delta (streaming)
  responseAudioDelta('response.audio.delta'),
  /// Response audio completed
  responseAudioDone('response.audio.done'),
  /// Response audio transcript delta (streaming)
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  /// Response audio transcript completed
  responseAudioTranscriptDone('response.audio_transcript.done'),
  /// Function call arguments delta (streaming)
  responseFunctionCallArgumentsDelta('response.function_call_arguments.delta'),
  /// Function call arguments completed
  responseFunctionCallArgumentsDone('response.function_call_arguments.done'),
  
  // === Other Events ===
  /// Rate limits have been updated
  rateLimitsUpdated('rate_limits.updated'),
  /// Transcription session has been updated
  transcriptionSessionUpdated('transcription_session.updated');

  final String value;
  const ServerEventType(this.value);
  
  /// Get ServerEventType from string value
  static ServerEventType? fromString(String value) {
    for (final type in ServerEventType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

/// Represents a function call from the AI
class FunctionCall {
  final String callId;
  final String name;
  final String arguments;

  FunctionCall({
    required this.callId,
    required this.name,
    required this.arguments,
  });
}

