import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread_json_codec.dart';

void main() {
  group('RealtimeThreadJsonCodec', () {
    test('decodes saved thread shape', () {
      final thread = RealtimeThreadJsonCodec.fromJson({
        'id': 'thread-1',
        'conversationId': 'conversation-1',
        'items': [
          {
            'id': 'message-1',
            'type': 'message',
            'role': 'user',
            'status': 'completed',
            'displayState': 'visible',
            'content': [
              {'type': 'audio', 'transcript': 'Hello', 'isDone': true},
            ],
          },
          {
            'id': 'call-1',
            'type': 'functionCall',
            'status': 'completed',
            'name': 'write_file',
            'arguments': '{}',
          },
          {
            'id': 'output-1',
            'type': 'functionCallOutput',
            'status': 'completed',
            'callId': 'call-1',
            'output': '{"ok":true}',
            'toolOutputDisposition': 'success',
          },
        ],
      });

      expect(thread.id, 'thread-1');
      expect(thread.conversationId, 'conversation-1');
      expect(thread.items, hasLength(3));
      expect(thread.items[0].role, RealtimeThreadItemRole.user);
      expect(thread.items[0].content.single, isA<RealtimeThreadAudioPart>());
      final audio = thread.items[0].content.single as RealtimeThreadAudioPart;
      expect(audio.transcript, 'Hello');
      expect(audio.audioChunks, isEmpty);
      expect(thread.items[1].type, RealtimeThreadItemType.functionCall);
      expect(
        thread.items[2].toolOutputDisposition,
        RealtimeToolOutputDisposition.success,
      );
    });

    test(
      'decodes product-usable saved history with multi-turn audio transcripts and repeated tools',
      () {
        final thread = RealtimeThreadJsonCodec.fromJson(
          _savedHistoryThreadJson(),
        );

        expect(thread.id, 't_saved_history');
        expect(thread.conversationId, 'cc_saved_history');
        expect(thread.items, hasLength(8));

        final firstUser = thread.items[0];
        expect(firstUser.type, RealtimeThreadItemType.message);
        expect(firstUser.role, RealtimeThreadItemRole.user);
        expect(firstUser.status, RealtimeThreadItemStatus.completed);
        expect(firstUser.isVisible, isTrue);
        expect(
          (firstUser.content.single as RealtimeThreadTextPart).text,
          'Ask the first saved-history question.',
        );

        final firstAssistant = thread.items[1];
        expect(firstAssistant.role, RealtimeThreadItemRole.assistant);
        final firstAssistantAudio =
            firstAssistant.content.single as RealtimeThreadAudioPart;
        expect(firstAssistantAudio.transcript, 'SESSION_HISTORY_FIRST_ANSWER');
        expect(firstAssistantAudio.audioChunks, isEmpty);

        final toolCalls = thread.items
            .where((item) => item.type == RealtimeThreadItemType.functionCall)
            .toList();
        expect(toolCalls, hasLength(2));
        expect(
          toolCalls.map((item) => item.name),
          everyElement('vhrp_history_probe'),
        );
        expect(
          toolCalls.map((item) => item.status),
          everyElement(RealtimeThreadItemStatus.completed),
        );

        final toolOutputs = thread.items
            .where(
              (item) => item.type == RealtimeThreadItemType.functionCallOutput,
            )
            .toList();
        expect(toolOutputs, hasLength(2));
        expect(
          toolOutputs.map((item) => item.toolOutputDisposition),
          everyElement(RealtimeToolOutputDisposition.success),
        );
        expect(
          toolOutputs.map((item) => item.output),
          containsAll(['TOOL_RESULT_ONE', 'TOOL_RESULT_TWO']),
        );

        final finalAssistant = thread.items.last;
        expect(finalAssistant.role, RealtimeThreadItemRole.assistant);
        final finalAssistantAudio =
            finalAssistant.content.single as RealtimeThreadAudioPart;
        expect(finalAssistantAudio.transcript, 'SESSION_HISTORY_FINAL_ANSWER');
      },
    );

    test('throws when item id is missing', () {
      expect(
        () => RealtimeThreadJsonCodec.fromJson({
          'id': 'thread-1',
          'items': [
            {'type': 'message'},
          ],
        }),
        throwsA(isA<RealtimeThreadJsonDecodeException>()),
      );
    });
  });
}

Map<String, Object?> _savedHistoryThreadJson() {
  return {
    'id': 't_saved_history',
    'conversationId': 'cc_saved_history',
    'items': [
      {
        'id': 'user-1',
        'type': 'message',
        'role': 'user',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'text',
            'text': 'Ask the first saved-history question.',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'assistant-1',
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'audio',
            'transcript': 'SESSION_HISTORY_FIRST_ANSWER',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'user-2',
        'type': 'message',
        'role': 'user',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'text',
            'text': 'Use the history tool twice.',
            'isDone': true,
          },
        ],
      },
      {
        'id': 'tool-call-1',
        'type': 'functionCall',
        'status': 'completed',
        'callId': 'call-1',
        'name': 'vhrp_history_probe',
        'arguments': '{}',
      },
      {
        'id': 'tool-output-1',
        'type': 'functionCallOutput',
        'status': 'completed',
        'callId': 'call-1',
        'output': 'TOOL_RESULT_ONE',
        'toolOutputDisposition': 'success',
      },
      {
        'id': 'tool-call-2',
        'type': 'functionCall',
        'status': 'completed',
        'callId': 'call-2',
        'name': 'vhrp_history_probe',
        'arguments': '{}',
      },
      {
        'id': 'tool-output-2',
        'type': 'functionCallOutput',
        'status': 'completed',
        'callId': 'call-2',
        'output': 'TOOL_RESULT_TWO',
        'toolOutputDisposition': 'success',
      },
      {
        'id': 'assistant-final',
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'displayState': 'visible',
        'content': [
          {
            'type': 'audio',
            'transcript': 'SESSION_HISTORY_FINAL_ANSWER',
            'isDone': true,
          },
        ],
      },
    ],
  };
}
