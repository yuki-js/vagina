import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/callv2/services/realtime/oai/realtime_command.dart';
import 'package:vagina/feat/callv2/services/realtime/oai/realtime_command_encoder.dart';

import 'fixture_loader.dart';

void main() {
  group('OaiRealtimeCommandEncoder', () {
    late OaiRealtimeCommandEncoder encoder;

    setUp(() {
      encoder = const OaiRealtimeCommandEncoder();
    });

    group('with text-only fixture', () {
      late RealtimeFixtureLoader loader;

      setUpAll(() async {
        loader = RealtimeFixtureLoader(
          'test/fixtures/oai_realtime/text_conversation.json',
        );
        await loader.load();
      });

      test('encodes session.update command matching fixture', () {
        final sentEvents = loader.sentEventsOfType('session.update');
        expect(sentEvents, hasLength(1));

        final fixturePayload = sentEvents.first;
        final fixtureSession =
            fixturePayload['session'] as Map<String, dynamic>;

        final command = OaiSessionUpdateCommand(session: fixtureSession);
        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('session.update'));
        expect(encoded['session'], isA<Map<String, dynamic>>());
        expect(encoded['session']['modalities'],
            equals(fixtureSession['modalities']));
        expect(
          encoded['session']['instructions'],
          equals(fixtureSession['instructions']),
        );
      });

      test('encodes conversation.item.create command matching fixture', () {
        final sentEvents = loader.sentEventsOfType('conversation.item.create');
        expect(sentEvents, hasLength(1));

        final fixturePayload = sentEvents.first;
        final fixtureItem = fixturePayload['item'] as Map<String, dynamic>;

        final command = OaiConversationItemCreateCommand(item: fixtureItem);
        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.create'));
        expect(encoded['item'], isA<Map<String, dynamic>>());
        expect(encoded['item']['type'], equals(fixtureItem['type']));
        expect(encoded['item']['role'], equals(fixtureItem['role']));
        expect(encoded['item']['content'], equals(fixtureItem['content']));
      });

      test('encodes response.create command matching fixture', () {
        final sentEvents = loader.sentEventsOfType('response.create');
        expect(sentEvents, hasLength(1));

        final fixturePayload = sentEvents.first;
        final fixtureResponse =
            fixturePayload['response'] as Map<String, dynamic>?;

        final command = OaiResponseCreateCommand(response: fixtureResponse);
        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('response.create'));
        if (fixtureResponse != null) {
          expect(encoded['response'], isA<Map<String, dynamic>>());
          expect(
            encoded['response']['modalities'],
            equals(fixtureResponse['modalities']),
          );
        }
      });
    });

    group('command encoding', () {
      test('encodes OaiSessionUpdateCommand', () {
        final command = OaiSessionUpdateCommand(
          session: {
            'modalities': ['text'],
            'instructions': 'Test instructions',
          },
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('session.update'));
        expect(encoded['session'], isA<Map<String, dynamic>>());
        expect(encoded['session']['modalities'], equals(['text']));
        expect(encoded['session']['instructions'], equals('Test instructions'));
      });

      test('encodes OaiTranscriptionSessionUpdateCommand', () {
        final command = OaiTranscriptionSessionUpdateCommand(
          session: {
            'model': 'whisper-1',
          },
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('transcription_session.update'));
        expect(encoded['session']['model'], equals('whisper-1'));
      });

      test('encodes OaiInputAudioBufferAppendCommand with base64', () {
        final audioBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final command =
            OaiInputAudioBufferAppendCommand(audioBytes: audioBytes);

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('input_audio_buffer.append'));
        expect(encoded['audio'], isA<String>());
        expect(encoded['audio'], equals(base64Encode(audioBytes)));
      });

      test('encodes OaiInputAudioBufferCommitCommand', () {
        const command = OaiInputAudioBufferCommitCommand();

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('input_audio_buffer.commit'));
        expect(encoded.length, equals(1)); // Only type field
      });

      test('encodes OaiInputAudioBufferClearCommand', () {
        const command = OaiInputAudioBufferClearCommand();

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('input_audio_buffer.clear'));
      });

      test('encodes OaiOutputAudioBufferClearCommand', () {
        const command = OaiOutputAudioBufferClearCommand();

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('output_audio_buffer.clear'));
      });

      test('encodes OaiConversationItemCreateCommand without previousItemId',
          () {
        final command = OaiConversationItemCreateCommand(
          item: {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'Hello'},
            ],
          },
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.create'));
        expect(encoded['item'], isA<Map<String, dynamic>>());
        expect(encoded.containsKey('previous_item_id'), isFalse);
      });

      test('encodes OaiConversationItemCreateCommand with previousItemId', () {
        final command = OaiConversationItemCreateCommand(
          previousItemId: 'item_123',
          item: {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'Hello'},
            ],
          },
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.create'));
        expect(encoded['previous_item_id'], equals('item_123'));
      });

      test('encodes OaiConversationItemDeleteCommand', () {
        const command = OaiConversationItemDeleteCommand(itemId: 'item_456');

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.delete'));
        expect(encoded['item_id'], equals('item_456'));
      });

      test('encodes OaiConversationItemRetrieveCommand', () {
        const command = OaiConversationItemRetrieveCommand(itemId: 'item_789');

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.retrieve'));
        expect(encoded['item_id'], equals('item_789'));
      });

      test('encodes OaiConversationItemTruncateCommand', () {
        const command = OaiConversationItemTruncateCommand(
          itemId: 'item_abc',
          contentIndex: 0,
          audioEndMs: 5000,
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('conversation.item.truncate'));
        expect(encoded['item_id'], equals('item_abc'));
        expect(encoded['content_index'], equals(0));
        expect(encoded['audio_end_ms'], equals(5000));
      });

      test('encodes OaiResponseCreateCommand without response', () {
        final command = OaiResponseCreateCommand();

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('response.create'));
        expect(encoded.containsKey('response'), isFalse);
      });

      test('encodes OaiResponseCreateCommand with response', () {
        final command = OaiResponseCreateCommand(
          response: {
            'modalities': ['text', 'audio'],
          },
        );

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('response.create'));
        expect(encoded['response'], isA<Map<String, dynamic>>());
        expect(encoded['response']['modalities'], equals(['text', 'audio']));
      });

      test('encodes OaiResponseCancelCommand', () {
        const command = OaiResponseCancelCommand();

        final encoded = encoder.encode(command);

        expect(encoded['type'], equals('response.cancel'));
      });
    });

    group('immutability', () {
      test('session data is immutable in OaiSessionUpdateCommand', () {
        final originalSession = {
          'modalities': ['text']
        };
        final command = OaiSessionUpdateCommand(session: originalSession);

        // Modify original
        originalSession['modalities'] = ['audio'];

        // Command should be unchanged
        final encoded = encoder.encode(command);
        expect(encoded['session']['modalities'], equals(['text']));
      });

      test('item data is immutable in OaiConversationItemCreateCommand', () {
        final originalItem = {
          'type': 'message',
          'role': 'user',
        };
        final command = OaiConversationItemCreateCommand(item: originalItem);

        // Modify original
        originalItem['role'] = 'assistant';

        // Command should be unchanged
        final encoded = encoder.encode(command);
        expect(encoded['item']['role'], equals('user'));
      });
    });
  });
}
