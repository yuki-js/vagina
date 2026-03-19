import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_binding.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connect_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connection_state.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_event.dart';

/// Integration tests for OaiRealtimeClient.
///
/// These tests connect to a real Azure OpenAI Realtime API endpoint.
///
/// To run these tests:
/// 1. Create /tmp/aoai_key.txt with your API key
/// 2. Run: flutter test test/lib/feat/call/services/realtime/oai/realtime_client_integration_test.dart
///
/// Skip these tests in CI by checking for the key file.
void main() {
  const keyPath = '/tmp/aoai_key.txt';
  const endpoint = 'https://oas-playground-swe.openai.azure.com';
  const deployment = 'gpt-realtime';
  const apiVersion = '2024-10-01-preview';

  group('OaiRealtimeClient integration tests', () {
    late String apiKey;

    setUpAll(() async {
      final keyFile = File(keyPath);
      if (!await keyFile.exists()) {
        throw StateError(
          'API key file not found: $keyPath\n'
          'Create this file with your Azure OpenAI API key to run integration tests.',
        );
      }
      apiKey = (await keyFile.readAsString()).trim();
      if (apiKey.isEmpty) {
        throw StateError('API key file is empty: $keyPath');
      }
    });

    test('connects and receives session.created event', () async {
      final client = OaiRealtimeClient();
      final config = AzureOpenAiRealtimeConnectConfig(
        apiKey: apiKey,
        endpoint: Uri.parse(endpoint),
        deployment: deployment,
        apiVersion: apiVersion,
      );

      // Listen for connection states
      final connectionStates = <OaiRealtimeConnectionState>[];
      final stateSubscription =
          client.connectionStates.listen(connectionStates.add);

      // Listen for session created event
      final sessionCreatedEvents = <OaiRealtimeSessionCreatedEvent>[];
      final eventSubscription = client.sessionCreatedEvents.listen(
        sessionCreatedEvents.add,
      );

      try {
        await client.connect(config);

        // Wait for session.created event
        await Future.delayed(const Duration(seconds: 2));

        // Verify we received session.created
        expect(sessionCreatedEvents, hasLength(1));
        final sessionCreated = sessionCreatedEvents.first;
        expect(sessionCreated.type, equals('session.created'));
        expect(sessionCreated.session.id, isNotEmpty);
        expect(sessionCreated.session.model, isNotNull);

        // Verify connection states
        expect(
          connectionStates
              .any((s) => s.phase == OaiRealtimeConnectionPhase.connecting),
          isTrue,
        );
        expect(
          connectionStates
              .any((s) => s.phase == OaiRealtimeConnectionPhase.connected),
          isTrue,
        );

        await client.disconnect();
      } finally {
        await stateSubscription.cancel();
        await eventSubscription.cancel();
        await client.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('sends session.update and receives session.updated', () async {
      final client = OaiRealtimeClient();
      final config = AzureOpenAiRealtimeConnectConfig(
        apiKey: apiKey,
        endpoint: Uri.parse(endpoint),
        deployment: deployment,
        apiVersion: apiVersion,
      );

      final sessionUpdatedEvents = <OaiRealtimeSessionUpdatedEvent>[];
      final eventSubscription = client.sessionUpdatedEvents.listen(
        sessionUpdatedEvents.add,
      );

      try {
        await client.connect(config);
        await Future.delayed(const Duration(seconds: 1));

        // Update session
        await client.updateSession({
          'modalities': ['text'],
          'instructions': 'You are a test assistant.',
        });

        // Wait for session.updated event
        await Future.delayed(const Duration(seconds: 2));

        expect(sessionUpdatedEvents, hasLength(1));
        final sessionUpdated = sessionUpdatedEvents.first;
        expect(sessionUpdated.type, equals('session.updated'));
        expect(sessionUpdated.session.modalities, contains('text'));
        expect(sessionUpdated.session.instructions, contains('test assistant'));

        await client.disconnect();
      } finally {
        await eventSubscription.cancel();
        await client.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('sends text message and receives response', () async {
      final client = OaiRealtimeClient();
      final config = AzureOpenAiRealtimeConnectConfig(
        apiKey: apiKey,
        endpoint: Uri.parse(endpoint),
        deployment: deployment,
        apiVersion: apiVersion,
      );

      final responseDoneEvents = <OaiRealtimeResponseDoneEvent>[];
      final textDoneEvents = <OaiRealtimeResponseOutputTextDoneEvent>[];

      final responseDoneSubscription = client.responseDoneEvents.listen(
        responseDoneEvents.add,
      );
      final textDoneSubscription = client.responseOutputTextDoneEvents.listen(
        textDoneEvents.add,
      );

      try {
        await client.connect(config);
        await Future.delayed(const Duration(seconds: 1));

        // Configure for text-only
        await client.updateSession({
          'modalities': ['text'],
          'instructions': 'Be very brief. Answer in one word or number only.',
        });

        await Future.delayed(const Duration(milliseconds: 500));

        // Send a simple question
        await client.createConversationItem(
          item: {
            'type': 'message',
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': 'What is 5 + 3? Just give the number.',
              },
            ],
          },
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Create response
        await client.createResponse(
          response: {
            'modalities': ['text'],
          },
        );

        // Wait for response
        await Future.delayed(const Duration(seconds: 5));

        // Verify we got a response
        expect(responseDoneEvents, hasLength(1));
        final responseDone = responseDoneEvents.first;
        expect(responseDone.response.status, equals('completed'));
        expect(responseDone.response.usage, isNotNull);

        // Verify we got text output
        expect(textDoneEvents, hasLength(1));
        final textDone = textDoneEvents.first;
        expect(textDone.text, isNotNull);
        expect(textDone.text, isNotEmpty);

        await client.disconnect();
      } finally {
        await responseDoneSubscription.cancel();
        await textDoneSubscription.cancel();
        await client.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('handles audio response modality', () async {
      final client = OaiRealtimeClient();
      final config = AzureOpenAiRealtimeConnectConfig(
        apiKey: apiKey,
        endpoint: Uri.parse(endpoint),
        deployment: deployment,
        apiVersion: apiVersion,
      );

      final audioDeltaEvents = <OaiRealtimeResponseOutputAudioDeltaEvent>[];
      final audioDoneEvents = <OaiRealtimeResponseOutputAudioDoneEvent>[];

      final audioDeltaSubscription =
          client.responseOutputAudioDeltaEvents.listen(
        audioDeltaEvents.add,
      );
      final audioDoneSubscription = client.responseOutputAudioDoneEvents.listen(
        audioDoneEvents.add,
      );

      try {
        await client.connect(config);
        await Future.delayed(const Duration(seconds: 1));

        // Configure for audio output
        await client.updateSession({
          'modalities': ['text', 'audio'],
          'instructions': 'Be very brief.',
          'voice': 'alloy',
        });

        await Future.delayed(const Duration(milliseconds: 500));

        // Send a simple message
        await client.createConversationItem(
          item: {
            'type': 'message',
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': 'Say hello.',
              },
            ],
          },
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Create response with audio
        await client.createResponse(
          response: {
            'modalities': ['text', 'audio'],
          },
        );

        // Wait for audio response
        await Future.delayed(const Duration(seconds: 8));

        // Verify we got audio deltas
        expect(audioDeltaEvents, isNotEmpty);
        for (final delta in audioDeltaEvents) {
          expect(delta.delta, isNotNull);
          expect(delta.delta, isNotEmpty);
        }

        // Verify we got audio done
        expect(audioDoneEvents, hasLength(1));

        await client.disconnect();
      } finally {
        await audioDeltaSubscription.cancel();
        await audioDoneSubscription.cancel();
        await client.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 50)));

    test('handles connection errors gracefully', () async {
      final client = OaiRealtimeClient();

      // Use invalid configuration
      final config = AzureOpenAiRealtimeConnectConfig(
        apiKey: 'invalid-key',
        endpoint: Uri.parse(endpoint),
        deployment: deployment,
        apiVersion: apiVersion,
      );

      final connectionErrors = <OaiRealtimeConnectionError>[];
      final errorSubscription = client.connectionErrors.listen(
        connectionErrors.add,
      );

      try {
        await expectLater(
          () => client.connect(config),
          throwsA(anything),
        );

        // Connection should have failed
        expect(client.isConnected, isFalse);
      } finally {
        await errorSubscription.cancel();
        await client.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
