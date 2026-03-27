import 'dart:typed_data';

sealed class OaiRealtimeCommand {
  final String type;

  const OaiRealtimeCommand(this.type);
}

final class OaiSessionUpdateCommand extends OaiRealtimeCommand {
  final Map<String, dynamic> session;

  OaiSessionUpdateCommand({required Map<String, dynamic> session})
      : session = Map<String, dynamic>.unmodifiable(session),
        super('session.update');
}

final class OaiTranscriptionSessionUpdateCommand extends OaiRealtimeCommand {
  final Map<String, dynamic> session;

  OaiTranscriptionSessionUpdateCommand({required Map<String, dynamic> session})
      : session = Map<String, dynamic>.unmodifiable(session),
        super('transcription_session.update');
}

final class OaiInputAudioBufferAppendCommand extends OaiRealtimeCommand {
  final Uint8List audioBytes;

  OaiInputAudioBufferAppendCommand({required this.audioBytes})
      : super('input_audio_buffer.append');
}

final class OaiInputAudioBufferCommitCommand extends OaiRealtimeCommand {
  const OaiInputAudioBufferCommitCommand() : super('input_audio_buffer.commit');
}

final class OaiInputAudioBufferClearCommand extends OaiRealtimeCommand {
  const OaiInputAudioBufferClearCommand() : super('input_audio_buffer.clear');
}

final class OaiOutputAudioBufferClearCommand extends OaiRealtimeCommand {
  const OaiOutputAudioBufferClearCommand() : super('output_audio_buffer.clear');
}

final class OaiConversationItemCreateCommand extends OaiRealtimeCommand {
  final String? previousItemId;
  final Map<String, dynamic> item;

  OaiConversationItemCreateCommand({
    this.previousItemId,
    required Map<String, dynamic> item,
  })  : item = Map<String, dynamic>.unmodifiable(item),
        super('conversation.item.create');
}

final class OaiConversationItemDeleteCommand extends OaiRealtimeCommand {
  final String itemId;

  const OaiConversationItemDeleteCommand({required this.itemId})
      : super('conversation.item.delete');
}

final class OaiConversationItemRetrieveCommand extends OaiRealtimeCommand {
  final String itemId;

  const OaiConversationItemRetrieveCommand({required this.itemId})
      : super('conversation.item.retrieve');
}

final class OaiConversationItemTruncateCommand extends OaiRealtimeCommand {
  final String itemId;
  final int contentIndex;
  final int audioEndMs;

  const OaiConversationItemTruncateCommand({
    required this.itemId,
    required this.contentIndex,
    required this.audioEndMs,
  }) : super('conversation.item.truncate');
}

final class OaiResponseCreateCommand extends OaiRealtimeCommand {
  final Map<String, dynamic>? response;

  OaiResponseCreateCommand({Map<String, dynamic>? response})
      : response = response == null
            ? null
            : Map<String, dynamic>.unmodifiable(response),
        super('response.create');
}

final class OaiResponseCancelCommand extends OaiRealtimeCommand {
  const OaiResponseCancelCommand() : super('response.cancel');
}
