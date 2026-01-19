import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/tools/tools.dart';

import '../mocks/mock_repositories.mocks.dart';

void main() {
  group('RealtimeApiClient default construction (coverage)', () {
    test('can be constructed without DI and exposes streams/getters', () async {
      final client = RealtimeApiClient();
      try {
        // Touch constructor default branches and simple getters.
        expect(client.isConnected, isFalse);
        expect(client.noiseReduction, isNotNull);

        // Touch stream getters that were previously uncovered in lcov.
        expect(client.responseDoneStream, isA<Stream<RealtimeResponse>>());
        expect(client.rateLimitsUpdatedStream, isA<Stream<List<RateLimit>>>());
      } finally {
        await client.dispose();
      }
    });
  });

  group('RealtimeApiClient preconditions (connect + not-connected guards)', () {
    late MockWebSocketService mockWs;
    late MockLogService mockLog;
    late RealtimeApiClient client;

    setUp(() {
      mockWs = MockWebSocketService();
      mockLog = MockLogService();

      when(mockWs.messages).thenAnswer((_) => const Stream.empty());
      when(mockWs.isConnected).thenAnswer((_) => false);
      when(mockWs.connect(any)).thenAnswer((_) async {});
      when(mockWs.disconnect()).thenAnswer((_) async {});
      when(mockWs.dispose()).thenAnswer((_) async {});
      when(mockWs.send(any)).thenAnswer((_) {});

      when(mockLog.info(any, any)).thenAnswer((_) {});
      when(mockLog.debug(any, any)).thenAnswer((_) {});
      when(mockLog.warn(any, any)).thenAnswer((_) {});
      when(mockLog.error(any, any)).thenAnswer((_) {});
      when(mockLog.websocket(any, any, any)).thenAnswer((_) {});

      client = RealtimeApiClient(webSocket: mockWs, logService: mockLog);

      addTearDown(() async {
        await client.dispose();
      });
    });

    test('throws and reports error when realtimeUrl is empty', () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      await expectLater(
        () => client.connect('', 'ABC123'),
        throwsA(isA<Exception>()),
      );
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.connect(any));

      expect(client.lastError, contains('Realtime URL is required'));
      expect(errors, isNotEmpty);
      expect(errors.last, contains('Realtime URL is required'));
    });

    test('throws and reports error when apiKey is empty', () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      await expectLater(
        () => client.connect(
          'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
          '',
        ),
        throwsA(isA<Exception>()),
      );
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.connect(any));

      expect(client.lastError, contains('API key is required'));
      expect(errors, isNotEmpty);
      expect(errors.last, contains('API key is required'));
    });

    test('sendAudio emits error and does not send when not connected',
        () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.sendAudio(Uint8List.fromList([1, 2, 3]));
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, ['Cannot send audio: not connected']);
    });

    test('commitAudioBuffer emits error and does not send when not connected',
        () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.commitAudioBuffer();
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, ['Cannot commit audio buffer: not connected']);
    });

    test('sendTextMessage emits error and does not send when not connected',
        () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.sendTextMessage('hello');
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, ['Cannot send message: not connected']);
    });

    test(
        'sendFunctionCallResult emits error and does not send when not connected',
        () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.sendFunctionCallResult('call-1', 'OK');
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, ['Cannot send function result: not connected']);
    });

    test('clearAudioBuffer does nothing when not connected', () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.clearAudioBuffer();
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, isEmpty);
    });

    test('cancelResponse does nothing when not connected', () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.cancelResponse();
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, isEmpty);
    });

    test('updateSessionConfig does nothing when not connected', () async {
      final errors = <String>[];
      final sub = client.errorStream.listen(errors.add);
      addTearDown(() async {
        await sub.cancel();
      });

      client.updateSessionConfig();
      await pumpEventQueue(times: 10);

      verifyNever(mockWs.send(any));
      expect(errors, isEmpty);
    });
  });

  group('RealtimeApiClient websocket packet flow (realistic UX)', () {
    const stepTimeout = Duration(seconds: 2);

    late MockWebSocketService mockWs;
    late MockLogService mockLog;

    late StreamController<Map<String, dynamic>> inbound;
    late StreamController<Map<String, dynamic>> outbound;

    late List<Map<String, dynamic>> sent;
    late bool connected;

    late RealtimeApiClient client;

    setUp(() {
      mockWs = MockWebSocketService();
      mockLog = MockLogService();

      inbound = StreamController<Map<String, dynamic>>.broadcast();
      outbound = StreamController<Map<String, dynamic>>.broadcast();

      sent = <Map<String, dynamic>>[];
      connected = true;

      when(mockWs.messages).thenAnswer((_) => inbound.stream);
      when(mockWs.isConnected).thenAnswer((_) => connected);
      when(mockWs.connect(any)).thenAnswer((_) async {});
      when(mockWs.disconnect()).thenAnswer((_) async {});
      when(mockWs.dispose()).thenAnswer((_) async {});
      when(mockWs.send(any)).thenAnswer((inv) {
        final arg = inv.positionalArguments.first;
        if (arg is Map<String, dynamic>) {
          final copy = Map<String, dynamic>.from(arg);
          sent.add(copy);
          outbound.add(copy);
        }
      });

      when(mockLog.info(any, any)).thenAnswer((_) {});
      when(mockLog.debug(any, any)).thenAnswer((_) {});
      when(mockLog.warn(any, any)).thenAnswer((_) {});
      when(mockLog.error(any, any)).thenAnswer((_) {});
      when(mockLog.websocket(any, any, any)).thenAnswer((_) {});

      client = RealtimeApiClient(webSocket: mockWs, logService: mockLog);

      // Make session.update deterministic-ish for verification.
      client.setVoiceAndInstructions('alloy', 'You are a helpful assistant');
      client.setTools(toolbox);
      client.setNoiseReduction('near');
    });

    tearDown(() async {
      await client.dispose();
      await inbound.close();
      await outbound.close();
    });

    test(
      'voice user turns + assistant double-stream + document toolchain scenario',
      () async {
        Future<Map<String, dynamic>> nextOutboundOfType(
          StreamQueue<Map<String, dynamic>> q,
          String type,
        ) async {
          while (true) {
            final msg = await q.next.timeout(stepTimeout);
            if (msg['type'] == type) return msg;
          }
        }

        final outboundQ = StreamQueue<Map<String, dynamic>>(outbound.stream);

        final speechStartedQ = StreamQueue<void>(client.speechStartedStream);
        final interruptQ = StreamQueue<void>(client.responseStartedStream);

        final userTranscriptDeltaQ =
            StreamQueue<String>(client.userTranscriptDeltaStream);
        final userTranscriptQ =
            StreamQueue<String>(client.userTranscriptStream);

        final assistantTranscriptQ =
            StreamQueue<String>(client.transcriptStream);
        final assistantTextDoneQ = StreamQueue<String>(client.textDoneStream);

        final responseAudioStartedQ =
            StreamQueue<void>(client.responseAudioStartedStream);
        final assistantAudioQ = StreamQueue<Uint8List>(client.audioStream);
        final assistantAudioDoneQ = StreamQueue<void>(client.audioDoneStream);

        final functionCallQ =
            StreamQueue<FunctionCall>(client.functionCallStream);

        final conversationCreatedQ =
            StreamQueue<RealtimeConversation>(client.conversationCreatedStream);

        var speechStartedCount = 0;
        var interruptCount = 0;

        final userTranscriptDeltas = <String>[];
        final userTranscripts = <String>[];

        final assistantTranscriptDeltas = <String>[];
        final assistantTextDone = <String>[];

        var responseAudioStartedCount = 0;
        final assistantAudioChunks = <Uint8List>[];
        var assistantAudioDoneCount = 0;

        final functionCalls = <FunctionCall>[];

        try {
          // =============================================================
          // Bootstrap: connect + session.created + conversation.created
          // =============================================================
          await client.connect(
            'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
            'ABC123',
          );

          verify(
            mockWs.connect(
              argThat(
                allOf(
                  contains('wss://example.openai.azure.com/openai/realtime'),
                  contains('api-version=2024-12-01'),
                  contains('deployment=test'),
                  contains('api-key=ABC123'),
                ),
              ),
            ),
          ).called(1);

          inbound.add({
            'type': 'session.created',
            'event_id': 'evt-1',
            'session': {
              'id': 'sess-1',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'tools': [],
            },
          });

          // Verify session.update was sent.
          final sessionUpdate =
              await nextOutboundOfType(outboundQ, 'session.update');
          final sessionUpdatePayload =
              (sessionUpdate['session'] as Map).cast<String, dynamic>();
          expect(sessionUpdatePayload['voice'], 'alloy');
          expect(sessionUpdatePayload['instructions'],
              'You are a helpful assistant');
          expect(sessionUpdatePayload['tools'], isA<List>());

          inbound.add({
            'type': 'conversation.created',
            'event_id': 'evt-2',
            'conversation': {
              'id': 'conv-1',
              'object': 'realtime.conversation',
            },
          });
          await conversationCreatedQ.next.timeout(stepTimeout);

          // =============================================================
          // Turn 1 (User voice): 「もしもし～？」
          // =============================================================
          inbound.add({
            'type': 'input_audio_buffer.speech_started',
            'audio_start_ms': 0,
            'item_id': 'user-item-1',
          });
          await speechStartedQ.next.timeout(stepTimeout);
          speechStartedCount++;
          await interruptQ.next.timeout(stepTimeout);
          interruptCount++;

          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': 'もし',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': 'もしもし',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': '～？',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'conversation.item.input_audio_transcription.completed',
            'item_id': 'user-item-1',
            'transcript': 'もしもし～？',
          });
          userTranscripts.add(await userTranscriptQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'input_audio_buffer.speech_stopped',
            'audio_end_ms': 800,
            'item_id': 'user-item-1',
          });

          // UX expectations: VAD detected + interrupt signal.
          expect(speechStartedCount, 1);
          expect(interruptCount, 1);
          // Delta packets are passed through as-is.
          expect(userTranscriptDeltas, ['もし', 'もしもし', '～？']);
          // Completed transcript is what UI should finalize.
          expect(userTranscripts, ['もしもし～？']);

          // =============================================================
          // Turn 1 (Assistant): 「こんにちは！どうしましたか？」 (text+audio)
          // =============================================================
          inbound.add({
            'type': 'rate_limits.updated',
            'rate_limits': [
              {
                'name': 'requests',
                'limit': 100,
                'remaining': 99,
                'reset_seconds': 1.5,
              }
            ],
          });
          inbound.add({
            'type': 'response.created',
            'response': {
              'id': 'resp-1',
              'object': 'realtime.response',
              'status': 'in_progress',
              'output': [],
            },
          });
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-1',
            'output_index': 0,
            'item': {
              'id': 'asst-item-1',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'assistant',
              'content': [],
            },
          });

          // Interleave text/audio like a real double stream.
          inbound.add({'type': 'response.text.delta', 'delta': 'こんにちは！'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.audio.delta',
            'delta': base64Encode([1, 2, 3]),
          });
          await responseAudioStartedQ.next.timeout(stepTimeout);
          responseAudioStartedCount++;
          assistantAudioChunks
              .add(await assistantAudioQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.text.delta', 'delta': 'どうしましたか？'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.audio.delta',
            'delta': base64Encode([4, 5]),
          });
          assistantAudioChunks
              .add(await assistantAudioQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.text.done',
            'item_id': 'asst-item-1',
            'text': 'こんにちは！どうしましたか？',
          });
          assistantTextDone
              .add(await assistantTextDoneQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.audio.done'});
          await assistantAudioDoneQ.next.timeout(stepTimeout);
          assistantAudioDoneCount++;

          inbound.add({
            'type': 'response.done',
            'response': {
              'id': 'resp-1',
              'object': 'realtime.response',
              'status': 'completed',
              'output': [],
              'usage': {
                'total_tokens': 3,
                'input_tokens': 1,
                'output_tokens': 2,
              },
            },
          });

          expect(assistantTranscriptDeltas.join(''), 'こんにちは！どうしましたか？');
          expect(assistantTextDone, ['こんにちは！どうしましたか？']);
          expect(responseAudioStartedCount, 1);
          expect(assistantAudioChunks, [
            Uint8List.fromList([1, 2, 3]),
            Uint8List.fromList([4, 5]),
          ]);
          expect(assistantAudioDoneCount, 1);

          // =============================================================
          // Turn 2 (User voice): 「仕様書書いてほしいんだけど。アイデア書を張るね」
          // =============================================================
          inbound.add({
            'type': 'input_audio_buffer.speech_started',
            'audio_start_ms': 900,
            'item_id': 'user-item-2',
          });
          await speechStartedQ.next.timeout(stepTimeout);
          speechStartedCount++;
          await interruptQ.next.timeout(stepTimeout);
          interruptCount++;

          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': '仕様書',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': '書いてほしい',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.delta',
            'delta': 'んだけど',
          });
          userTranscriptDeltas
              .add(await userTranscriptDeltaQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'conversation.item.input_audio_transcription.completed',
            'item_id': 'user-item-2',
            'transcript': '仕様書書いてほしいんだけど。アイデア書を張るね',
          });
          userTranscripts.add(await userTranscriptQ.next.timeout(stepTimeout));
          inbound.add({
            'type': 'input_audio_buffer.speech_stopped',
            'audio_end_ms': 1800,
            'item_id': 'user-item-2',
          });

          expect(speechStartedCount, 2);
          expect(interruptCount, 2);
          expect(userTranscripts.last, '仕様書書いてほしいんだけど。アイデア書を張るね');

          // =============================================================
          // Turn 2 (Assistant): 「承知しました、コンテンツはどこですか？」 (text+audio)
          // =============================================================
          inbound.add({
            'type': 'rate_limits.updated',
            'rate_limits': [
              {
                'name': 'requests',
                'limit': 100,
                'remaining': 98,
                'reset_seconds': 1.5,
              }
            ],
          });
          inbound.add({
            'type': 'response.created',
            'response': {
              'id': 'resp-2',
              'object': 'realtime.response',
              'status': 'in_progress',
              'output': [],
            },
          });
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-2',
            'output_index': 0,
            'item': {
              'id': 'asst-item-2',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'assistant',
              'content': [],
            },
          });

          inbound.add({'type': 'response.text.delta', 'delta': '承知しました、'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.audio.delta',
            'delta': base64Encode([9, 9, 9]),
          });
          await responseAudioStartedQ.next.timeout(stepTimeout);
          responseAudioStartedCount++;
          assistantAudioChunks
              .add(await assistantAudioQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.text.delta', 'delta': 'コンテンツはどこですか？'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.audio.delta',
            'delta': base64Encode([8, 8]),
          });
          assistantAudioChunks
              .add(await assistantAudioQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.text.done',
            'item_id': 'asst-item-2',
            'text': '承知しました、コンテンツはどこですか？',
          });
          assistantTextDone
              .add(await assistantTextDoneQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.audio.done'});
          await assistantAudioDoneQ.next.timeout(stepTimeout);
          assistantAudioDoneCount++;

          inbound.add({
            'type': 'response.done',
            'response': {
              'id': 'resp-2',
              'object': 'realtime.response',
              'status': 'completed',
              'output': [],
              'usage': {
                'total_tokens': 3,
                'input_tokens': 1,
                'output_tokens': 2,
              },
            },
          });

          expect(assistantTextDone.last, '承知しました、コンテンツはどこですか？');

          // =============================================================
          // User pastes a long idea document (text input)
          // =============================================================
          final ideaText = '# アイデア書\n\n1. アイデアは…\n\n2. もっと長い本文…\n';
          client.sendTextMessage(ideaText);

          final userItemCreate = await nextOutboundOfType(
            outboundQ,
            'conversation.item.create',
          );
          expect(userItemCreate['type'], 'conversation.item.create');
          final userResponseCreate =
              await nextOutboundOfType(outboundQ, 'response.create');
          expect(userResponseCreate['type'], 'response.create');

          // =============================================================
          // Toolchain 1: document_patch (fail)
          // =============================================================
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-2',
            'output_index': 1,
            'item': {
              'id': 'item-call-patch-1',
              'object': 'realtime.item',
              'type': 'function_call',
              'call_id': 'call-patch-1',
              'name': 'document_patch',
              'arguments': '',
            },
          });
          inbound.add({
            'type': 'response.function_call_arguments.delta',
            'call_id': 'call-patch-1',
            'delta': '{"patch":"..."}',
          });
          inbound.add({
            'type': 'response.function_call_arguments.done',
            'call_id': 'call-patch-1',
          });

          functionCalls.add(await functionCallQ.next.timeout(stepTimeout));
          expect(functionCalls.last.name, 'document_patch');

          client.sendFunctionCallResult(
            'call-patch-1',
            'ERROR: document_patch failed',
          );

          // Verify outbound is function_call_output then response.create
          final patchItemCreate = await nextOutboundOfType(
            outboundQ,
            'conversation.item.create',
          );
          final patchOutItem =
              (patchItemCreate['item'] as Map).cast<String, dynamic>();
          expect(patchOutItem['type'], 'function_call_output');
          expect(patchOutItem['call_id'], 'call-patch-1');
          expect(patchOutItem['output'], 'ERROR: document_patch failed');

          await nextOutboundOfType(outboundQ, 'response.create');

          // =============================================================
          // Toolchain 2: document_read
          // =============================================================
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-2',
            'output_index': 2,
            'item': {
              'id': 'item-call-read-1',
              'object': 'realtime.item',
              'type': 'function_call',
              'call_id': 'call-read-1',
              'name': 'document_read',
              'arguments': '',
            },
          });
          inbound.add({
            'type': 'response.function_call_arguments.delta',
            'call_id': 'call-read-1',
            'delta': '{"tabId":"artifact_1"}',
          });
          inbound.add({
            'type': 'response.function_call_arguments.done',
            'call_id': 'call-read-1',
          });

          functionCalls.add(await functionCallQ.next.timeout(stepTimeout));
          expect(functionCalls.last.name, 'document_read');

          client.sendFunctionCallResult('call-read-1', '既存のファイルデータが続く…');

          final readItemCreate =
              await nextOutboundOfType(outboundQ, 'conversation.item.create');
          final readOutItem =
              (readItemCreate['item'] as Map).cast<String, dynamic>();
          expect(readOutItem['type'], 'function_call_output');
          expect(readOutItem['call_id'], 'call-read-1');

          await nextOutboundOfType(outboundQ, 'response.create');

          // =============================================================
          // Toolchain 3: document_overwrite
          // =============================================================
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-2',
            'output_index': 3,
            'item': {
              'id': 'item-call-overwrite-1',
              'object': 'realtime.item',
              'type': 'function_call',
              'call_id': 'call-overwrite-1',
              'name': 'document_overwrite',
              'arguments': '',
            },
          });
          inbound.add({
            'type': 'response.function_call_arguments.delta',
            'call_id': 'call-overwrite-1',
            'delta': '{"content":"# アイデア書..."}',
          });
          inbound.add({
            'type': 'response.function_call_arguments.done',
            'call_id': 'call-overwrite-1',
          });

          functionCalls.add(await functionCallQ.next.timeout(stepTimeout));
          expect(functionCalls.last.name, 'document_overwrite');

          client.sendFunctionCallResult('call-overwrite-1', 'OK');

          final overwriteItemCreate =
              await nextOutboundOfType(outboundQ, 'conversation.item.create');
          final overwriteOutItem =
              (overwriteItemCreate['item'] as Map).cast<String, dynamic>();
          expect(overwriteOutItem['type'], 'function_call_output');
          expect(overwriteOutItem['call_id'], 'call-overwrite-1');

          await nextOutboundOfType(outboundQ, 'response.create');

          // =============================================================
          // Final assistant confirmation: 「ノートパッドに記載しました。」 (text+audio)
          // =============================================================
          inbound.add({
            'type': 'rate_limits.updated',
            'rate_limits': [
              {
                'name': 'requests',
                'limit': 100,
                'remaining': 97,
                'reset_seconds': 1.5,
              }
            ],
          });
          inbound.add({
            'type': 'response.created',
            'response': {
              'id': 'resp-3',
              'object': 'realtime.response',
              'status': 'in_progress',
              'output': [],
            },
          });
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-3',
            'output_index': 0,
            'item': {
              'id': 'asst-item-3',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'assistant',
              'content': [],
            },
          });

          inbound.add({'type': 'response.text.delta', 'delta': 'ノートパッドに'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.audio.delta',
            'delta': base64Encode([7, 7, 7]),
          });
          await responseAudioStartedQ.next.timeout(stepTimeout);
          responseAudioStartedCount++;
          assistantAudioChunks
              .add(await assistantAudioQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.text.delta', 'delta': '記載しました。'});
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.text.done',
            'item_id': 'asst-item-3',
            'text': 'ノートパッドに記載しました。',
          });
          assistantTextDone
              .add(await assistantTextDoneQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.audio.done'});
          await assistantAudioDoneQ.next.timeout(stepTimeout);
          assistantAudioDoneCount++;

          inbound.add({
            'type': 'response.done',
            'response': {
              'id': 'resp-3',
              'object': 'realtime.response',
              'status': 'completed',
              'output': [],
              'usage': {
                'total_tokens': 3,
                'input_tokens': 1,
                'output_tokens': 2,
              },
            },
          });

          expect(assistantTextDone.last, 'ノートパッドに記載しました。');

          // Outbound sanity
          final types = sent.map((m) => m['type']).toList(growable: false);
          expect(types, contains('session.update'));
          expect(types, contains('conversation.item.create'));
          expect(types, contains('response.create'));
        } finally {
          await outboundQ.cancel(immediate: true);
          await speechStartedQ.cancel(immediate: true);
          await interruptQ.cancel(immediate: true);
          await userTranscriptDeltaQ.cancel(immediate: true);
          await userTranscriptQ.cancel(immediate: true);
          await assistantTranscriptQ.cancel(immediate: true);
          await assistantTextDoneQ.cancel(immediate: true);
          await responseAudioStartedQ.cancel(immediate: true);
          await assistantAudioQ.cancel(immediate: true);
          await assistantAudioDoneQ.cancel(immediate: true);
          await functionCallQ.cancel(immediate: true);
          await conversationCreatedQ.cancel(immediate: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'text-only chat: user sends text, assistant responds with response.text.* only',
      () async {
        Future<Map<String, dynamic>> nextOutboundOfType(
          StreamQueue<Map<String, dynamic>> q,
          String type,
        ) async {
          while (true) {
            final msg = await q.next.timeout(stepTimeout);
            if (msg['type'] == type) return msg;
          }
        }

        final outboundQ = StreamQueue<Map<String, dynamic>>(outbound.stream);
        final conversationCreatedQ =
            StreamQueue<RealtimeConversation>(client.conversationCreatedStream);

        final assistantTranscriptQ =
            StreamQueue<String>(client.transcriptStream);
        final assistantTextDeltaQ = StreamQueue<String>(client.textDeltaStream);
        final assistantTextDoneQ = StreamQueue<String>(client.textDoneStream);

        final assistantTranscriptDeltas = <String>[];
        final assistantTextDeltas = <String>[];
        final assistantTextDone = <String>[];

        try {
          await client.connect(
            'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
            'ABC123',
          );

          inbound.add({
            'type': 'session.created',
            'event_id': 'evt-1',
            'session': {
              'id': 'sess-1',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'tools': [],
            },
          });
          await nextOutboundOfType(outboundQ, 'session.update');

          inbound.add({
            'type': 'conversation.created',
            'event_id': 'evt-2',
            'conversation': {
              'id': 'conv-1',
              'object': 'realtime.conversation',
            },
          });
          await conversationCreatedQ.next.timeout(stepTimeout);

          // User sends text message.
          client.sendTextMessage('hello');
          await nextOutboundOfType(outboundQ, 'conversation.item.create');
          await nextOutboundOfType(outboundQ, 'response.create');

          // Assistant responds (text-only).
          inbound.add({
            'type': 'response.created',
            'response': {
              'id': 'resp-text-1',
              'object': 'realtime.response',
              'status': 'in_progress',
              'output': [],
            },
          });
          inbound.add({
            'type': 'response.output_item.added',
            'response_id': 'resp-text-1',
            'output_index': 0,
            'item': {
              'id': 'asst-item-text-1',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'assistant',
              'content': [],
            },
          });

          inbound.add({'type': 'response.text.delta', 'delta': 'こんにちは'});
          assistantTextDeltas
              .add(await assistantTextDeltaQ.next.timeout(stepTimeout));
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({'type': 'response.text.delta', 'delta': '！'});
          assistantTextDeltas
              .add(await assistantTextDeltaQ.next.timeout(stepTimeout));
          assistantTranscriptDeltas
              .add(await assistantTranscriptQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.text.done',
            'item_id': 'asst-item-text-1',
            'text': 'こんにちは！',
          });
          assistantTextDone
              .add(await assistantTextDoneQ.next.timeout(stepTimeout));

          inbound.add({
            'type': 'response.done',
            'response': {
              'id': 'resp-text-1',
              'object': 'realtime.response',
              'status': 'completed',
              'output': [],
            },
          });

          expect(assistantTextDeltas.join(''), 'こんにちは！');
          expect(assistantTranscriptDeltas.join(''), 'こんにちは！');
          expect(assistantTextDone, ['こんにちは！']);
        } finally {
          await outboundQ.cancel(immediate: true);
          await conversationCreatedQ.cancel(immediate: true);
          await assistantTranscriptQ.cancel(immediate: true);
          await assistantTextDeltaQ.cancel(immediate: true);
          await assistantTextDoneQ.cancel(immediate: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'conversation lifecycle: item.created/deleted/truncated/retrieved events',
      () async {
        Future<Map<String, dynamic>> nextOutboundOfType(
          StreamQueue<Map<String, dynamic>> q,
          String type,
        ) async {
          while (true) {
            final msg = await q.next.timeout(stepTimeout);
            if (msg['type'] == type) return msg;
          }
        }

        final outboundQ = StreamQueue<Map<String, dynamic>>(outbound.stream);

        final conversationCreatedQ =
            StreamQueue<RealtimeConversation>(client.conversationCreatedStream);
        final itemCreatedQ =
            StreamQueue<ConversationItem>(client.conversationItemCreatedStream);
        final itemDeletedQ =
            StreamQueue<String>(client.conversationItemDeletedStream);

        final createdItems = <ConversationItem>[];
        final deletedItemIds = <String>[];

        try {
          await client.connect(
            'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
            'ABC123',
          );

          inbound.add({
            'type': 'session.created',
            'event_id': 'evt-1',
            'session': {
              'id': 'sess-1',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'tools': [],
            },
          });
          await nextOutboundOfType(outboundQ, 'session.update');

          inbound.add({
            'type': 'conversation.created',
            'event_id': 'evt-2',
            'conversation': {
              'id': 'conv-1',
              'object': 'realtime.conversation',
            },
          });
          await conversationCreatedQ.next.timeout(stepTimeout);

          // Server creates a user message item.
          inbound.add({
            'type': 'conversation.item.created',
            'event_id': 'evt-item-created-1',
            'previous_item_id': null,
            'item': {
              'id': 'item-1',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'hello'}
              ],
            },
          });
          createdItems.add(await itemCreatedQ.next.timeout(stepTimeout));
          expect(createdItems.last.id, 'item-1');

          // Truncate an earlier assistant audio item (log-only, should not throw).
          inbound.add({
            'type': 'conversation.item.truncated',
            'event_id': 'evt-item-trunc-1',
            'item_id': 'asst-audio-1',
            'content_index': 0,
            'audio_end_ms': 250,
          });

          // Retrieve an item (log-only, should not throw).
          inbound.add({
            'type': 'conversation.item.retrieved',
            'event_id': 'evt-item-retrieved-1',
            'item': {
              'id': 'item-1',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'hello'}
              ],
            },
          });

          // Delete the item.
          inbound.add({
            'type': 'conversation.item.deleted',
            'event_id': 'evt-item-deleted-1',
            'item_id': 'item-1',
          });
          deletedItemIds.add(await itemDeletedQ.next.timeout(stepTimeout));
          expect(deletedItemIds, ['item-1']);
        } finally {
          await outboundQ.cancel(immediate: true);
          await conversationCreatedQ.cancel(immediate: true);
          await itemCreatedQ.cancel(immediate: true);
          await itemDeletedQ.cancel(immediate: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'session update roundtrip: updateSessionConfig sends session.update and handles session.updated',
      () async {
        Future<Map<String, dynamic>> nextOutboundOfType(
          StreamQueue<Map<String, dynamic>> q,
          String type,
        ) async {
          while (true) {
            final msg = await q.next.timeout(stepTimeout);
            if (msg['type'] == type) return msg;
          }
        }

        final outboundQ = StreamQueue<Map<String, dynamic>>(outbound.stream);

        final sessionCreatedQ =
            StreamQueue<RealtimeSession>(client.sessionCreatedStream);
        final sessionUpdatedQ =
            StreamQueue<RealtimeSession>(client.sessionUpdatedStream);

        try {
          await client.connect(
            'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
            'ABC123',
          );

          inbound.add({
            'type': 'session.created',
            'event_id': 'evt-1',
            'session': {
              'id': 'sess-1',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'tools': [],
            },
          });
          await sessionCreatedQ.next.timeout(stepTimeout);

          // First session.update is sent as part of session.created handling.
          await nextOutboundOfType(outboundQ, 'session.update');

          // Change config and request another update.
          client.setVoiceAndInstructions('alloy', 'Updated instructions');
          client.setNoiseReduction('far');
          client.updateSessionConfig();

          final sessionUpdate2 =
              await nextOutboundOfType(outboundQ, 'session.update');
          final sessionUpdatePayload2 =
              (sessionUpdate2['session'] as Map).cast<String, dynamic>();
          expect(sessionUpdatePayload2['voice'], 'alloy');
          expect(sessionUpdatePayload2['instructions'], 'Updated instructions');

          // Server acknowledges with session.updated.
          inbound.add({
            'type': 'session.updated',
            'event_id': 'evt-2',
            'session': {
              'id': 'sess-1',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'turn_detection': {'type': 'server_vad'},
              'input_audio_transcription': {'model': 'whisper-1'},
              'tools': [
                {'type': 'function', 'name': 'document_patch'}
              ],
            },
          });

          final updated = await sessionUpdatedQ.next.timeout(stepTimeout);
          expect(updated.id, 'sess-1');
        } finally {
          await outboundQ.cancel(immediate: true);
          await sessionCreatedQ.cancel(immediate: true);
          await sessionUpdatedQ.cancel(immediate: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'coverage: log-only handlers + error branches + unknown event types',
      () async {
        Future<Map<String, dynamic>> nextOutboundOfType(
          StreamQueue<Map<String, dynamic>> q,
          String type,
        ) async {
          while (true) {
            final msg = await q.next.timeout(stepTimeout);
            if (msg['type'] == type) return msg;
          }
        }

        final outboundQ = StreamQueue<Map<String, dynamic>>(outbound.stream);
        final errorQ = StreamQueue<String>(client.errorStream);

        final transcriptQ = StreamQueue<String>(client.transcriptStream);
        final rateLimitsQ =
            StreamQueue<List<RateLimit>>(client.rateLimitsUpdatedStream);
        final responseDoneQ =
            StreamQueue<RealtimeResponse>(client.responseDoneStream);

        try {
          await client.connect(
            'https://example.openai.azure.com/openai/realtime?api-version=2024-12-01&deployment=test',
            'ABC123',
          );

          // 1) Session bootstrap
          inbound.add({
            'type': 'session.created',
            'event_id': 'evt-boot-1',
            'session': {
              'id': 'sess-boot',
              'object': 'realtime.session',
              'model': 'gpt-4o-realtime-preview',
              'tools': [],
            },
          });
          await nextOutboundOfType(outboundQ, 'session.update');

          // 2) Messages.listen onError branch
          inbound.addError('boom');
          final wsErr = await errorQ.next.timeout(stepTimeout);
          expect(wsErr, contains('boom'));

          // 3) Unknown / missing type branch
          inbound.add({});
          inbound.add({'type': 'unknown.event'});

          // 4) Session updated else branch (missing session)
          inbound.add({
            'type': 'session.updated',
            'event_id': 'evt-sess-upd-no-payload',
          });

          // 5) transcription_session.updated (log-only)
          inbound.add({
            'type': 'transcription_session.updated',
            'event_id': 'evt-transcription-only',
          });

          // 6) conversation.created else branch (missing conversation)
          inbound.add({
            'type': 'conversation.created',
            'event_id': 'evt-conv-created-no-payload',
          });

          // 7) input_audio transcription empty transcript branch
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.completed',
            'event_id': 'evt-user-transcript-empty',
            'item_id': 'user-item-empty',
            'transcript': '',
          });

          // 8) transcription failed branches (with/without error payload)
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.failed',
            'event_id': 'evt-user-transcript-failed-1',
            'item_id': 'user-item-failed',
            'error': {'message': 'x', 'code': 'y'},
          });
          inbound.add({
            'type': 'conversation.item.input_audio_transcription.failed',
            'event_id': 'evt-user-transcript-failed-2',
            'item_id': 'user-item-failed',
          });

          // 9) Input audio buffer log-only events
          inbound.add({
            'type': 'input_audio_buffer.committed',
            'event_id': 'evt-committed',
          });
          inbound.add({
            'type': 'input_audio_buffer.cleared',
            'event_id': 'evt-cleared'
          });

          // 10) WebRTC-only output audio buffer events (log-only)
          inbound.add({
            'type': 'output_audio_buffer.started',
            'event_id': 'evt-out-start',
            'response_id': 'r1',
          });
          inbound.add({
            'type': 'output_audio_buffer.stopped',
            'event_id': 'evt-out-stop',
            'response_id': 'r1',
          });
          inbound.add({
            'type': 'output_audio_buffer.cleared',
            'event_id': 'evt-out-clear',
            'response_id': 'r1',
          });

          // 11) response.output_item.done (log-only)
          inbound.add({
            'type': 'response.output_item.done',
            'event_id': 'evt-out-item-done',
            'item': {
              'id': 'asst-item-done',
              'object': 'realtime.item',
              'type': 'message',
              'role': 'assistant',
              'status': 'completed',
              'content': [],
            },
          });

          // 12) response.content_part.* (log-only)
          inbound.add({
            'type': 'response.content_part.added',
            'event_id': 'evt-part-added',
            'item_id': 'asst-item-1',
            'content_index': 0,
            'part': {'type': 'text', 'text': 'hello'},
          });
          inbound.add({
            'type': 'response.content_part.done',
            'event_id': 'evt-part-done',
            'item_id': 'asst-item-1',
            'part': {'type': 'text', 'text': 'hello'},
          });

          // 13) response.audio_transcript.* (delta should flow to transcript)
          inbound.add({
            'type': 'response.audio_transcript.delta',
            'event_id': 'evt-aud-tr-d',
            'delta': 'テスト',
          });
          expect(await transcriptQ.next.timeout(stepTimeout), 'テスト');
          inbound.add({
            'type': 'response.audio_transcript.done',
            'event_id': 'evt-aud-tr-done',
            'transcript': 'テスト',
            'item_id': 'x',
          });

          // 14) rate_limits.updated should emit stream
          inbound.add({
            'type': 'rate_limits.updated',
            'event_id': 'evt-rl',
            'rate_limits': [
              {
                'name': 'requests',
                'limit': 100,
                'remaining': 1,
                'reset_seconds': 0.5,
              }
            ],
          });
          final limits = await rateLimitsQ.next.timeout(stepTimeout);
          expect(limits, isNotEmpty);

          // 15) error event branch: null payload
          inbound.add({'type': 'error', 'event_id': 'evt-err-null'});
          final apiErr = await errorQ.next.timeout(stepTimeout);
          expect(apiErr, contains('Unknown error'));

          // 16) response.done should emit
          inbound.add({
            'type': 'response.done',
            'event_id': 'evt-resp-done',
            'response': {
              'id': 'resp-1',
              'object': 'realtime.response',
              'status': 'completed',
              'output': [],
            },
          });
          final done = await responseDoneQ.next.timeout(stepTimeout);
          expect(done.id, 'resp-1');
        } finally {
          await outboundQ.cancel(immediate: true);
          await errorQ.cancel(immediate: true);
          await transcriptQ.cancel(immediate: true);
          await rateLimitsQ.cancel(immediate: true);
          await responseDoneQ.cancel(immediate: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
