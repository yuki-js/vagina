import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/services/text_agent_service.dart';
import 'package:vagina/feat/call/services/tool_runner.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

import 'text_agent_service_test_support.dart';

void main() {
  group('TextAgentService server query path', () {
    test('returns final text from the florval query endpoint', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': 'The caller asked for a summary.',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      final text = await started.service.sendQuery(
        'agent-1',
        'Summarize what the caller said.',
      );

      expect(text, 'The caller asked for a summary.');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/text-agents/agent-1/query');
      expect(
        adapter.requestJsonBodies.single,
        containsPair('voiceSessionId', 'vs_0123456789abcdef'),
      );
      expect(
        adapter.requestJsonBodies.single,
        containsPair('prompt', 'Summarize what the caller said.'),
      );
      expect(
        adapter.requestJsonBodies.single['requestId'],
        allOf(isA<String>(), startsWith('req_')),
      );
      expect(
        adapter.requestJsonBodies.single,
        containsPair('toolResult', null),
      );
    });

    test(
      'executes requested tools and submits tool results back through florval',
      () async {
        var requestCount = 0;
        final adapter = _RecordingAdapter((_) async {
          requestCount += 1;
          if (requestCount == 1) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'requires_tool',
              'toolCalls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'tc_1',
                  'name': 'get_current_time',
                  'arguments': '{}',
                },
              ],
            });
          }
          if (requestCount == 2) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'completed',
              'text': 'It is done.',
            });
          }
          fail('Unexpected request count: $requestCount');
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        final text = await started.service.sendQuery(
          'agent-1',
          'What time is it?',
        );

        expect(text, 'It is done.');
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.map((request) => request.path),
          everyElement('/text-agents/agent-1/query'),
        );

        final firstBody = adapter.requestJsonBodies[0];
        final secondBody = adapter.requestJsonBodies[1];
        expect(firstBody['requestId'], secondBody['requestId']);
        expect(firstBody['voiceSessionId'], secondBody['voiceSessionId']);
        expect(firstBody, containsPair('prompt', 'What time is it?'));
        expect(secondBody, containsPair('prompt', null));

        final toolResult = Map<String, dynamic>.from(
          secondBody['toolResult'] as Map,
        );
        expect(toolResult, containsPair('toolCallId', 'tc_1'));
        expect(toolResult, containsPair('isError', false));

        final toolOutput = Map<String, dynamic>.from(
          jsonDecode(toolResult['output'] as String) as Map,
        );
        expect(toolOutput, contains('current_time'));
        expect(toolOutput, containsPair('timezone', 'local'));
      },
    );

    test('surfaces server-reported failure responses clearly', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'failed',
          'error': <String, dynamic>{
            'code': 'provider_unavailable',
            'message': 'Text agent provider is temporarily unavailable.',
          },
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      await expectLater(
        started.service.sendQuery('agent-1', 'hello'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('provider_unavailable') &&
                error.toString().contains(
                  'Text agent provider is temporarily unavailable.',
                ),
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('fails clearly on an unknown server status', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'paused',
          'text': 'unused',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      await expectLater(
        started.service.sendQuery('agent-1', 'hello'),
        throwsA(
          predicate((error) => error.toString().contains('unknown status')),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('fails clearly on completed response without text', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{'status': 'completed'});
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      await expectLater(
        started.service.sendQuery('agent-1', 'hello'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('malformed completed response') &&
                error.toString().contains('missing text'),
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      'fails clearly on requires_tool response without tool calls',
      () async {
        final adapter = _RecordingAdapter((_) async {
          return _jsonResponse(200, <String, dynamic>{
            'status': 'requires_tool',
          });
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        await expectLater(
          started.service.sendQuery('agent-1', 'hello'),
          throwsA(
            predicate(
              (error) =>
                  error.toString().contains(
                    'malformed requires_tool response',
                  ) &&
                  error.toString().contains('missing toolCalls'),
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test('submits tool execution exceptions as tool errors', () async {
      var requestCount = 0;
      final adapter = _RecordingAdapter((_) async {
        requestCount += 1;
        if (requestCount == 1) {
          return _jsonResponse(200, <String, dynamic>{
            'status': 'requires_tool',
            'toolCalls': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tc_error',
                'name': 'query_text_agent',
                'arguments': jsonEncode(<String, dynamic>{
                  'agent_id': 'agent-1',
                  'prompt': 'nested query',
                }),
              },
            ],
          });
        }
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': 'Recovered after tool error.',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      final text = await started.service.sendQuery('agent-1', 'hello');

      expect(text, 'Recovered after tool error.');
      expect(adapter.requests, hasLength(2));
      final toolResult = Map<String, dynamic>.from(
        adapter.requestJsonBodies[1]['toolResult'] as Map,
      );
      expect(toolResult, containsPair('toolCallId', 'tc_error'));
      expect(toolResult, containsPair('isError', true));
      final output = Map<String, dynamic>.from(
        jsonDecode(toolResult['output'] as String) as Map,
      );
      expect(output, containsPair('success', false));
      expect(output['error'], contains('Tool execution failed'));
    });

    test('submits multiple tool calls in server-provided order', () async {
      var requestCount = 0;
      final adapter = _RecordingAdapter((_) async {
        requestCount += 1;
        if (requestCount == 1 || requestCount == 2) {
          return _jsonResponse(200, <String, dynamic>{
            'status': 'requires_tool',
            'toolCalls': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tc_first',
                'name': 'get_current_time',
                'arguments': '{}',
              },
              <String, dynamic>{
                'id': 'tc_second',
                'name': 'query_text_agent',
                'arguments': jsonEncode(<String, dynamic>{
                  'agent_id': 'agent-1',
                  'prompt': 'nested query',
                }),
              },
            ],
          });
        }
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': 'Both tools handled.',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      final text = await started.service.sendQuery('agent-1', 'hello');

      expect(text, 'Both tools handled.');
      expect(adapter.requests, hasLength(3));
      final firstToolResult = Map<String, dynamic>.from(
        adapter.requestJsonBodies[1]['toolResult'] as Map,
      );
      final secondToolResult = Map<String, dynamic>.from(
        adapter.requestJsonBodies[2]['toolResult'] as Map,
      );
      expect(firstToolResult, containsPair('toolCallId', 'tc_first'));
      expect(firstToolResult, containsPair('isError', false));
      expect(secondToolResult, containsPair('toolCallId', 'tc_second'));
      expect(secondToolResult, containsPair('isError', true));
    });

    test('fails clearly after the maximum query iteration count', () async {
      var requestCount = 0;
      final adapter = _RecordingAdapter((_) async {
        requestCount += 1;
        return _jsonResponse(200, <String, dynamic>{
          'status': 'requires_tool',
          'toolCalls': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tc_$requestCount',
              'name': 'get_current_time',
              'arguments': '{}',
            },
          ],
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);

      await expectLater(
        started.service.sendQuery('agent-1', 'hello'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('maximum number of iterations') &&
                error.toString().contains('20'),
          ),
        ),
      );
      expect(adapter.requests, hasLength(21));
    });

    test('fails fast when there is no active voice session id', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': 'unused',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: null,
      );
      addTearDown(started.dispose);

      await expectLater(
        started.service.sendQuery('agent-1', 'hello'),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('active voice session'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
      expect(adapter.requestJsonBodies, isEmpty);
    });
  });
}

Future<_StartedTextAgentService> _startService({
  required HttpClientAdapter adapter,
  required String? voiceSessionId,
}) async {
  final notepadService = createTestNotepadService();
  final realtimeService = createTestRealtimeService(sessionId: voiceSessionId);
  final service = TextAgentService(
    agents: const <TextAgentInfo>[
      TextAgentInfo(
        id: 'agent-1',
        name: 'Research Assistant',
        description: 'Looks things up',
        prompt: 'Help with research',
        apiConfig: ServerBackedTextAgentApiConfig(
          textModelId: 'text-agent-prod',
        ),
      ),
    ],
    notepadService: notepadService,
    realtimeService: realtimeService,
    apiClient: createTestApiClient(adapter),
  );
  final toolRunner = ToolRunner(
    filesystemApi: _NoopFilesystemApi(),
    callApi: _NoopCallApi(),
    textAgentApi: _NoopTextAgentApi(),
  );

  service.setToolRunner(toolRunner);

  await notepadService.start();
  await realtimeService.start();
  await toolRunner.start();
  await service.start();

  return _StartedTextAgentService(
    service: service,
    notepadService: notepadService,
    realtimeService: realtimeService,
    toolRunner: toolRunner,
  );
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

final class _StartedTextAgentService {
  final TextAgentService service;
  final NotepadService notepadService;
  final RealtimeService realtimeService;
  final ToolRunner toolRunner;

  _StartedTextAgentService({
    required this.service,
    required this.notepadService,
    required this.realtimeService,
    required this.toolRunner,
  });

  Future<void> dispose() async {
    await service.dispose();
    await toolRunner.dispose();
    await realtimeService.dispose();
    await notepadService.dispose();
  }
}

final class _RecordingAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions request) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Map<String, dynamic>> requestJsonBodies = <Map<String, dynamic>>[];

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
        requestJsonBodies.add(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(bodyBytes)) as Map),
        );
      }
    } else if (options.data is Map) {
      requestJsonBodies.add(Map<String, dynamic>.from(options.data as Map));
    }

    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _NoopCallApi implements CallApi {
  @override
  Future<bool> endCall({String? endContext}) async {
    return true;
  }
}

final class _NoopFilesystemApi implements FilesystemApi {
  @override
  Future<void> closeFile(String path) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    return null;
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return const <String>[];
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<void> move(String fromPath, String toPath) async {}

  @override
  Future<void> openFile(String path, String content) async {}

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    return null;
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {}

  @override
  Future<void> write(String path, String content) async {}
}

final class _NoopTextAgentApi implements TextAgentApi {
  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    void Function() Function(void Function())? onCancel,
  }) {
    throw UnimplementedError('sendQuery() is not used in this test.');
  }
}
