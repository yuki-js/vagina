import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_event.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_event_parser.dart';

import 'fixture_loader.dart';

void main() {
  group('OaiRealtimeEventParser', () {
    late OaiRealtimeEventParser parser;

    setUp(() {
      parser = const OaiRealtimeEventParser();
    });

    group('with text-only fixture', () {
      late RealtimeFixtureLoader loader;

      setUpAll(() async {
        loader = RealtimeFixtureLoader(
          'test/fixtures/oai_realtime/text_conversation.json',
        );
        await loader.load();
      });

      test('parses all received events without errors', () {
        final receivedEvents = loader.receivedEvents;
        expect(receivedEvents.length, greaterThan(0));

        for (final payload in receivedEvents) {
          expect(
            () => parser.parse(payload),
            returnsNormally,
            reason: 'Failed to parse event type: ${payload['type']}',
          );
        }
      });

      test('parses session.created event', () {
        final events = loader.receivedEventsOfType('session.created');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeSessionCreatedEvent>());

        final sessionCreated = parsed as OaiRealtimeSessionCreatedEvent;
        expect(sessionCreated.type, equals('session.created'));
        expect(sessionCreated.eventId, isNotNull);
        expect(sessionCreated.session, isNotNull);
        expect(sessionCreated.session.id, isNotEmpty);
        expect(sessionCreated.session.model, isNotNull);
      });

      test('parses session.updated event', () {
        final events = loader.receivedEventsOfType('session.updated');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeSessionUpdatedEvent>());

        final sessionUpdated = parsed as OaiRealtimeSessionUpdatedEvent;
        expect(sessionUpdated.type, equals('session.updated'));
        expect(sessionUpdated.session.rawJson['modalities'], contains('text'));
      });

      test('parses conversation.item.created event', () {
        final events = loader.receivedEventsOfType('conversation.item.created');
        expect(events, isNotEmpty);

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeConversationItemCreatedEvent>());

        final itemCreated = parsed as OaiRealtimeConversationItemCreatedEvent;
        expect(itemCreated.type, equals('conversation.item.created'));
        expect(itemCreated.item, isNotNull);
        expect(itemCreated.item.id, isNotEmpty);
      });

      test('parses response.created event', () {
        final events = loader.receivedEventsOfType('response.created');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseCreatedEvent>());

        final responseCreated = parsed as OaiRealtimeResponseCreatedEvent;
        expect(responseCreated.type, equals('response.created'));
        expect(responseCreated.response, isNotNull);
        expect(responseCreated.response.id, isNotEmpty);
        expect(responseCreated.response.status, equals('in_progress'));
      });

      test('parses response.output_item.added event', () {
        final events = loader.receivedEventsOfType('response.output_item.added');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseOutputItemAddedEvent>());

        final itemAdded = parsed as OaiRealtimeResponseOutputItemAddedEvent;
        expect(itemAdded.type, equals('response.output_item.added'));
        expect(itemAdded.responseId, isNotNull);
        expect(itemAdded.item, isNotNull);
      });

      test('parses response.content_part.added event', () {
        final events = loader.receivedEventsOfType('response.content_part.added');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseContentPartAddedEvent>());

        final partAdded = parsed as OaiRealtimeResponseContentPartAddedEvent;
        expect(partAdded.type, equals('response.content_part.added'));
        expect(partAdded.part, isNotNull);
        expect(partAdded.part.type, equals('text'));
      });

      test('parses response.text.delta events', () {
        final events = loader.receivedEventsOfType('response.text.delta');
        expect(events, isNotEmpty);

        for (final payload in events) {
          final parsed = parser.parse(payload);
          expect(parsed, isA<OaiRealtimeResponseOutputTextDeltaEvent>());

          final textDelta = parsed as OaiRealtimeResponseOutputTextDeltaEvent;
          expect(textDelta.type, equals('response.output_text.delta'));
          expect(textDelta.delta, isNotNull);
        }
      });

      test('parses response.text.done event', () {
        final events = loader.receivedEventsOfType('response.text.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseOutputTextDoneEvent>());

        final textDone = parsed as OaiRealtimeResponseOutputTextDoneEvent;
        expect(textDone.type, equals('response.output_text.done'));
        expect(textDone.text, isNotNull);
        expect(textDone.text, isNotEmpty);
      });

      test('parses response.content_part.done event', () {
        final events = loader.receivedEventsOfType('response.content_part.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseContentPartDoneEvent>());
      });

      test('parses response.output_item.done event', () {
        final events = loader.receivedEventsOfType('response.output_item.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseOutputItemDoneEvent>());

        final itemDone = parsed as OaiRealtimeResponseOutputItemDoneEvent;
        expect(itemDone.item.status, equals('completed'));
      });

      test('parses response.done event', () {
        final events = loader.receivedEventsOfType('response.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseDoneEvent>());

        final responseDone = parsed as OaiRealtimeResponseDoneEvent;
        expect(responseDone.type, equals('response.done'));
        expect(responseDone.response.status, equals('completed'));
        expect(responseDone.response.usage, isNotNull);
      });
    });

    group('with audio-response fixture', () {
      late RealtimeFixtureLoader loader;

      setUpAll(() async {
        loader = RealtimeFixtureLoader(
          'test/fixtures/oai_realtime/audio_conversation.json',
        );
        await loader.load();
      });

      test('parses all received events without errors', () {
        final receivedEvents = loader.receivedEvents;
        expect(receivedEvents.length, greaterThan(0));

        for (final payload in receivedEvents) {
          expect(
            () => parser.parse(payload),
            returnsNormally,
            reason: 'Failed to parse event type: ${payload['type']}',
          );
        }
      });

      test('parses response.audio_transcript.delta events', () {
        final events = loader.receivedEventsOfType('response.audio_transcript.delta');
        expect(events, isNotEmpty);

        for (final payload in events) {
          final parsed = parser.parse(payload);
          expect(parsed, isA<OaiRealtimeResponseOutputAudioTranscriptDeltaEvent>());

          final audioDelta =
              parsed as OaiRealtimeResponseOutputAudioTranscriptDeltaEvent;
          expect(audioDelta.type, equals('response.output_audio_transcript.delta'));
          expect(audioDelta.delta, isNotNull);
        }
      });

      test('parses response.audio.delta events', () {
        final events = loader.receivedEventsOfType('response.audio.delta');
        expect(events, isNotEmpty);

        for (final payload in events) {
          final parsed = parser.parse(payload);
          expect(parsed, isA<OaiRealtimeResponseOutputAudioDeltaEvent>());

          final audioDelta = parsed as OaiRealtimeResponseOutputAudioDeltaEvent;
          expect(audioDelta.type, equals('response.output_audio.delta'));
          expect(audioDelta.delta, isNotNull);
          expect(audioDelta.delta, isNotEmpty);
        }
      });

      test('parses response.audio.done event', () {
        final events = loader.receivedEventsOfType('response.audio.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseOutputAudioDoneEvent>());

        final audioDone = parsed as OaiRealtimeResponseOutputAudioDoneEvent;
        expect(audioDone.type, equals('response.output_audio.done'));
      });

      test('parses response.audio_transcript.done event', () {
        final events = loader.receivedEventsOfType('response.audio_transcript.done');
        expect(events, hasLength(1));

        final parsed = parser.parse(events.first);
        expect(parsed, isA<OaiRealtimeResponseOutputAudioTranscriptDoneEvent>());

        final transcriptDone =
            parsed as OaiRealtimeResponseOutputAudioTranscriptDoneEvent;
        expect(transcriptDone.type, equals('response.output_audio_transcript.done'));
        expect(transcriptDone.transcript, isNotNull);
        expect(transcriptDone.transcript, isNotEmpty);
      });
    });

    group('error handling', () {
      test('throws OaiRealtimeProtocolException for missing type', () {
        expect(
          () => parser.parse({}),
          throwsA(isA<OaiRealtimeProtocolException>()),
        );
      });

      test('throws OaiRealtimeProtocolException for empty type', () {
        expect(
          () => parser.parse({'type': ''}),
          throwsA(isA<OaiRealtimeProtocolException>()),
        );
      });

      test('throws OaiRealtimeProtocolException for unsupported type', () {
        expect(
          () => parser.parse({'type': 'unknown.event'}),
          throwsA(isA<OaiRealtimeProtocolException>()),
        );
      });

      test('throws OaiRealtimeProtocolException for invalid payload shape', () {
        expect(
          () => parser.parse({
            'type': 'session.created',
            'session': 'not-an-object',
          }),
          throwsA(isA<OaiRealtimeProtocolException>()),
        );
      });
    });
  });
}
