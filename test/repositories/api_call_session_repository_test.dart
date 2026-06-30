import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/repositories/api_call_session_repository.dart';

void main() {
  group('ApiCallSessionRepository', () {
    test('maps list response into CallSessionPage', () async {
      final adapter = _RecordingAdapter((request) async {
        expect(request.path, '/sessions');
        expect(request.queryParameters['limit'], 10);
        expect(request.queryParameters['cursor'], 'next-page');
        return _jsonResponse(200, {
          'items': [
            {
              'id': '11111111-1111-1111-1111-111111111111',
              'startedAt': '2026-01-02T03:04:05Z',
              'endedAt': '2026-01-02T03:05:06Z',
            },
          ],
          'nextCursor': 'after-one',
        });
      });
      final repository = ApiCallSessionRepository(apiClient: _client(adapter));

      final page = await repository.list(cursor: 'next-page', limit: 10);

      expect(page.items, hasLength(1));
      expect(page.items.single.id, '11111111-1111-1111-1111-111111111111');
      expect(
        page.items.single.startedAt,
        DateTime.parse('2026-01-02T03:04:05Z'),
      );
      expect(page.items.single.endedAt, DateTime.parse('2026-01-02T03:05:06Z'));
      expect(page.items.single.duration, 61);
      expect(page.nextCursor, 'after-one');
    });

    test('maps detail response and decodes saved thread', () async {
      final adapter = _RecordingAdapter((request) async {
        expect(request.path, '/sessions/11111111-1111-1111-1111-111111111111');
        return _jsonResponse(200, {
          'id': '11111111-1111-1111-1111-111111111111',
          'startedAt': '2026-01-02T03:04:05Z',
          'endedAt': '2026-01-02T03:05:06Z',
          'speedDialId': 'speed-dial-1',
          'voiceAgentId': 'voice-agent-1',
          'thread': {
            'id': 'thread-1',
            'conversationId': 'conversation-1',
            'items': [
              {
                'id': 'item-1',
                'type': 'message',
                'role': 'assistant',
                'status': 'completed',
                'displayState': 'visible',
                'content': [
                  {'type': 'text', 'text': 'Hello', 'isDone': true},
                ],
              },
            ],
          },
        });
      });
      final repository = ApiCallSessionRepository(apiClient: _client(adapter));

      final session = await repository.getById(
        '11111111-1111-1111-1111-111111111111',
      );

      expect(session, isNotNull);
      expect(session!.speedDialId, 'speed-dial-1');
      expect(session.voiceAgentId, 'voice-agent-1');
      expect(session.thread!.id, 'thread-1');
      expect(session.thread!.conversationId, 'conversation-1');
      expect(
        session.thread!.items.single.role,
        RealtimeThreadItemRole.assistant,
      );
      final part = session.thread!.items.single.content.single;
      expect(part, isA<RealtimeThreadTextPart>());
      expect((part as RealtimeThreadTextPart).text, 'Hello');
    });

    test('maps product-usable multi-turn tool history response', () async {
      final adapter = _RecordingAdapter((request) async {
        expect(request.path, '/sessions/33333333-3333-3333-3333-333333333333');
        return _jsonResponse(200, {
          'id': '33333333-3333-3333-3333-333333333333',
          'startedAt': '2026-01-02T03:04:05Z',
          'endedAt': '2026-01-02T03:05:06Z',
          'speedDialId': 'history-tool-speed-dial',
          'voiceAgentId': 'voice-agent-prod-cc',
          'thread': _savedHistoryThreadJson(),
        });
      });
      final repository = ApiCallSessionRepository(apiClient: _client(adapter));

      final session = await repository.getById(
        '33333333-3333-3333-3333-333333333333',
      );

      expect(session, isNotNull);
      expect(session!.speedDialId, 'history-tool-speed-dial');
      expect(session.voiceAgentId, 'voice-agent-prod-cc');
      expect(session.visibleThreadItemCount, 8);
      final thread = session.thread!;
      expect(
        thread.items.where(
          (item) => item.type == RealtimeThreadItemType.message,
        ),
        hasLength(4),
      );
      expect(
        thread.items.where(
          (item) => item.type == RealtimeThreadItemType.functionCall,
        ),
        hasLength(2),
      );
      final finalPart =
          thread.items.last.content.single as RealtimeThreadAudioPart;
      expect(finalPart.transcript, 'SESSION_HISTORY_FINAL_ANSWER');
    });

    test('surfaces saved thread decode failures', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, {
          'id': '11111111-1111-1111-1111-111111111111',
          'startedAt': '2026-01-02T03:04:05Z',
          'voiceAgentId': 'voice-agent-1',
          'thread': {
            'id': 'thread-1',
            'items': [
              {'type': 'message'},
            ],
          },
        });
      });
      final repository = ApiCallSessionRepository(apiClient: _client(adapter));

      await expectLater(
        repository.getById('11111111-1111-1111-1111-111111111111'),
        throwsA(isA<SavedThreadCannotBeDisplayedException>()),
      );
    });

    test('bulkDelete sends ids and returns deleted count', () async {
      final adapter = _RecordingAdapter((request) async {
        expect(request.path, '/sessions/bulk-delete');
        return _jsonResponse(200, {'deletedCount': 2});
      });
      final repository = ApiCallSessionRepository(apiClient: _client(adapter));

      final count = await repository.bulkDelete([
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
      ]);

      expect(count, 2);
      final body =
          jsonDecode(adapter.requestBodies.single) as Map<String, dynamic>;
      expect(body['ids'], [
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
      ]);
    });
  });
}

VaginaApiClient _client(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return VaginaApiClient(
    dioOverride: dio,
    getAccessToken: ({bool forceRefresh = false}) async => 'test-token',
  );
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
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

final class _RecordingAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions request) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<String> requestBodies = <String>[];

  _RecordingAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bodyBytes = <int>[];
      await for (final chunk in requestStream) {
        bodyBytes.addAll(chunk);
      }
      if (bodyBytes.isNotEmpty) {
        requestBodies.add(utf8.decode(bodyBytes));
      }
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
