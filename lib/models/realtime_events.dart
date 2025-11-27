/// Events sent by the client to the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-client-events
enum ClientEventType {
  sessionUpdate('session.update'),
  inputAudioBufferAppend('input_audio_buffer.append'),
  inputAudioBufferCommit('input_audio_buffer.commit'),
  inputAudioBufferClear('input_audio_buffer.clear'),
  conversationItemCreate('conversation.item.create'),
  conversationItemTruncate('conversation.item.truncate'),
  conversationItemDelete('conversation.item.delete'),
  responseCreate('response.create'),
  responseCancel('response.cancel');

  final String value;
  const ClientEventType(this.value);
}

/// Events received from the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-server-events
enum ServerEventType {
  error('error'),
  sessionCreated('session.created'),
  sessionUpdated('session.updated'),
  conversationCreated('conversation.created'),
  inputAudioBufferCommitted('input_audio_buffer.committed'),
  inputAudioBufferCleared('input_audio_buffer.cleared'),
  inputAudioBufferSpeechStarted('input_audio_buffer.speech_started'),
  inputAudioBufferSpeechStopped('input_audio_buffer.speech_stopped'),
  conversationItemCreated('conversation.item.created'),
  conversationItemInputAudioTranscriptionCompleted(
      'conversation.item.input_audio_transcription.completed'),
  conversationItemInputAudioTranscriptionFailed(
      'conversation.item.input_audio_transcription.failed'),
  conversationItemTruncated('conversation.item.truncated'),
  conversationItemDeleted('conversation.item.deleted'),
  responseCreated('response.created'),
  responseDone('response.done'),
  responseOutputItemAdded('response.output_item.added'),
  responseOutputItemDone('response.output_item.done'),
  responseContentPartAdded('response.content_part.added'),
  responseContentPartDone('response.content_part.done'),
  responseTextDelta('response.text.delta'),
  responseTextDone('response.text.done'),
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  responseAudioTranscriptDone('response.audio_transcript.done'),
  responseAudioDelta('response.audio.delta'),
  responseAudioDone('response.audio.done'),
  responseFunctionCallArgumentsDelta('response.function_call_arguments.delta'),
  responseFunctionCallArgumentsDone('response.function_call_arguments.done'),
  rateLimitsUpdated('rate_limits.updated');

  final String value;
  const ServerEventType(this.value);
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
