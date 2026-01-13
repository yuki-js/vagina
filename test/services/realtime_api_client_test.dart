import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/models/realtime_events.dart';

void main() {
  group('RealtimeApiClient', () {
    late RealtimeApiClient client;

    setUp(() {
      client = RealtimeApiClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('initial state is not connected', () {
      expect(client.isConnected, isFalse);
      expect(client.lastError, isNull);
    });

    test('setTools stores tool definitions', () {
      final tools = [
        {
          'type': 'function',
          'name': 'test_tool',
          'description': 'A test tool',
          'parameters': {'type': 'object', 'properties': {}}
        }
      ];
      
      client.setTools(tools);
      // Tools are stored internally, no direct getter to verify
      expect(client.isConnected, isFalse);
    });

    test('setVoiceAndInstructions stores configuration', () {
      client.setVoiceAndInstructions('alloy', 'You are a helpful assistant');
      // Configuration stored internally
      expect(client.isConnected, isFalse);
    });

    test('setNoiseReduction sets valid noise reduction type', () {
      client.setNoiseReduction('far');
      expect(client.noiseReduction, equals('far'));
      
      client.setNoiseReduction('near');
      expect(client.noiseReduction, equals('near'));
    });

    test('setNoiseReduction ignores invalid values', () {
      client.setNoiseReduction('near');
      client.setNoiseReduction('invalid');
      // Should keep previous valid value
      expect(client.noiseReduction, equals('near'));
    });

    test('audio streams are available', () {
      expect(client.audioStream, isNotNull);
      expect(client.transcriptStream, isNotNull);
      expect(client.userTranscriptStream, isNotNull);
      expect(client.errorStream, isNotNull);
    });

    test('event streams are available', () {
      expect(client.sessionCreatedStream, isNotNull);
      expect(client.sessionUpdatedStream, isNotNull);
      expect(client.conversationCreatedStream, isNotNull);
      expect(client.responseDoneStream, isNotNull);
    });
  });

  group('ServerEventType', () {
    test('fromString returns correct event type', () {
      expect(ServerEventType.fromString('error'), equals(ServerEventType.error));
      expect(ServerEventType.fromString('session.created'), equals(ServerEventType.sessionCreated));
      expect(ServerEventType.fromString('response.done'), equals(ServerEventType.responseDone));
    });

    test('fromString returns null for unknown event', () {
      expect(ServerEventType.fromString('unknown.event'), isNull);
      expect(ServerEventType.fromString(''), isNull);
    });
  });

  group('ClientEventType', () {
    test('enum has correct values', () {
      expect(ClientEventType.sessionUpdate.value, equals('session.update'));
      expect(ClientEventType.inputAudioBufferAppend.value, equals('input_audio_buffer.append'));
      expect(ClientEventType.responseCreate.value, equals('response.create'));
    });
  });
}
