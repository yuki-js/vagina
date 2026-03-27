import 'dart:convert';

import 'realtime_command.dart';

final class OaiRealtimeCommandEncoder {
  const OaiRealtimeCommandEncoder();

  Map<String, dynamic> encode(OaiRealtimeCommand command) {
    switch (command) {
      case OaiSessionUpdateCommand():
        return {
          'type': command.type,
          'session': command.session,
        };
      case OaiTranscriptionSessionUpdateCommand():
        return {
          'type': command.type,
          'session': command.session,
        };
      case OaiInputAudioBufferAppendCommand():
        return {
          'type': command.type,
          'audio': base64Encode(command.audioBytes),
        };
      case OaiInputAudioBufferCommitCommand():
        return {
          'type': command.type,
        };
      case OaiInputAudioBufferClearCommand():
        return {
          'type': command.type,
        };
      case OaiOutputAudioBufferClearCommand():
        return {
          'type': command.type,
        };
      case OaiConversationItemCreateCommand():
        return {
          'type': command.type,
          if (command.previousItemId != null)
            'previous_item_id': command.previousItemId,
          'item': command.item,
        };
      case OaiConversationItemDeleteCommand():
        return {
          'type': command.type,
          'item_id': command.itemId,
        };
      case OaiConversationItemRetrieveCommand():
        return {
          'type': command.type,
          'item_id': command.itemId,
        };
      case OaiConversationItemTruncateCommand():
        return {
          'type': command.type,
          'item_id': command.itemId,
          'content_index': command.contentIndex,
          'audio_end_ms': command.audioEndMs,
        };
      case OaiResponseCreateCommand():
        return {
          'type': command.type,
          if (command.response != null) 'response': command.response,
        };
      case OaiResponseCancelCommand():
        return {
          'type': command.type,
        };
    }
  }
}
