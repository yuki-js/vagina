import 'dart:async';
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
import 'package:vagina/feat/call/services/toolapi/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/tools.dart';

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
      expect(adapter.requests.single.sendTimeout, const Duration(minutes: 30));
      expect(
        adapter.requests.single.receiveTimeout,
        const Duration(minutes: 30),
      );
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
      final toolSchemaNames = _toolSchemaNames(
        adapter.requestJsonBodies.single,
      );
      expect(toolSchemaNames, contains('calculator'));
      expect(toolSchemaNames, contains('list_available_agents'));
      expect(toolSchemaNames, contains('say_hello_to_agent'));
      expect(toolSchemaNames, isNot(contains('end_call')));
    });

    test('attaches the remembered last user image when requested', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': 'The image was reviewed.',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
      );
      addTearDown(started.dispose);
      started.service.rememberLastUserImage(
        Uint8List.fromList(<int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
        name: 'whiteboard.png',
      );

      final text = await started.service.sendQuery(
        'agent-1',
        'Analyze the last image.',
        attachLastUserImage: true,
      );

      expect(text, 'The image was reviewed.');
      final images =
          adapter.requestJsonBodies.single['images'] as List<dynamic>;
      final image = Map<String, dynamic>.from(images.single as Map);
      expect(image['dataUri'], startsWith('data:image/png;base64,'));
      expect(image['detail'], 'auto');
      expect(image['name'], 'whiteboard.png');
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
        expect(_toolSchemaNames(firstBody), contains('list_available_agents'));
        expect(_toolSchemaNames(secondBody), _toolSchemaNames(firstBody));

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

    test(
      'returns nested calculator result through say_hello_to_agent tool execution',
      () async {
        var requestCount = 0;
        final adapter = _RecordingAdapter((_) async {
          requestCount += 1;
          if (requestCount == 1) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'requires_tool',
              'toolCalls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'tc_calc',
                  'name': 'calculator',
                  'arguments': jsonEncode(<String, dynamic>{
                    'expression': '6 * 7',
                  }),
                },
              ],
            });
          }
          if (requestCount == 2) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'completed',
              'text': 'The answer is 42.',
            });
          }
          fail('Unexpected request count: $requestCount');
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        final parentToolOutput = await started.toolRunner.execute(
          'say_hello_to_agent',
          jsonEncode(<String, dynamic>{
            'agent_id': 'agent-1',
            'prompt': 'Calculate 6 * 7 for the caller.',
          }),
        );

        final parentToolResult = Map<String, dynamic>.from(
          jsonDecode(parentToolOutput) as Map,
        );
        expect(parentToolResult, containsPair('success', true));
        expect(parentToolResult, containsPair('text', 'The answer is 42.'));
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.map((request) => request.path),
          everyElement('/text-agents/agent-1/query'),
        );

        final firstBody = adapter.requestJsonBodies[0];
        final secondBody = adapter.requestJsonBodies[1];
        expect(
          firstBody,
          containsPair('voiceSessionId', 'vs_0123456789abcdef'),
        );
        expect(
          firstBody,
          containsPair('prompt', 'Calculate 6 * 7 for the caller.'),
        );
        expect(
          firstBody['requestId'],
          allOf(isA<String>(), startsWith('req_')),
        );
        expect(
          secondBody,
          containsPair('voiceSessionId', 'vs_0123456789abcdef'),
        );
        expect(secondBody['requestId'], firstBody['requestId']);
        expect(secondBody, containsPair('prompt', null));

        final toolResult = Map<String, dynamic>.from(
          secondBody['toolResult'] as Map,
        );
        expect(toolResult, containsPair('toolCallId', 'tc_calc'));
        expect(toolResult, containsPair('isError', false));

        final toolOutput = Map<String, dynamic>.from(
          jsonDecode(toolResult['output'] as String) as Map,
        );
        expect(toolOutput, containsPair('success', true));
        expect(toolOutput, containsPair('expression', '6 * 7'));
        expect(toolOutput, containsPair('result', 42.0));
      },
    );

    test(
      'executes same-agent recursion as an ordinary nested tool call',
      () async {
        var requestCount = 0;
        final adapter = _RecordingAdapter((_) async {
          requestCount += 1;
          if (requestCount == 1) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'requires_tool',
              'toolCalls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'tc_nested_text_agent',
                  'name': 'say_hello_to_agent',
                  'arguments': jsonEncode(<String, dynamic>{
                    'agent_id': 'agent-1',
                    'prompt': 'Confirm recursively.',
                  }),
                },
              ],
            });
          }
          if (requestCount == 2) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'completed',
              'text': 'Nested confirmation.',
            });
          }
          if (requestCount == 3) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'completed',
              'text': 'Outer agent consumed nested confirmation.',
            });
          }
          fail('Unexpected request count: $requestCount');
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        final text = await started.service.sendQuery('agent-1', 'hello');

        expect(text, 'Outer agent consumed nested confirmation.');
        expect(adapter.requests, hasLength(3));
        expect(adapter.requestJsonBodies[0], containsPair('prompt', 'hello'));
        expect(
          adapter.requestJsonBodies[1],
          containsPair('prompt', 'Confirm recursively.'),
        );
        expect(adapter.requestJsonBodies[2], containsPair('prompt', null));

        final toolResult = Map<String, dynamic>.from(
          adapter.requestJsonBodies[2]['toolResult'] as Map,
        );
        expect(toolResult, containsPair('toolCallId', 'tc_nested_text_agent'));
        expect(toolResult, containsPair('isError', false));
        final toolOutput = Map<String, dynamic>.from(
          jsonDecode(toolResult['output'] as String) as Map,
        );
        expect(toolOutput, containsPair('success', true));
        expect(toolOutput, containsPair('text', 'Nested confirmation.'));
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
                'name': 'unknown_tool_for_error_path',
                'arguments': '{}',
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
      expect(
        output['error'],
        contains('Tool is not available in the current call session'),
      );
    });

    test('normalizes success false tool output as an error', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        jsonEncode(<String, dynamic>{'success': false, 'error': 'failed'}),
      );

      expect(toolResult, containsPair('toolCallId', 'tc_normalize'));
      expect(
        toolResult,
        containsPair('output', '{"success":false,"error":"failed"}'),
      );
      expect(toolResult, containsPair('isError', true));
    });

    test('normalizes isError true tool output as an error', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        jsonEncode(<String, dynamic>{'isError': true}),
      );

      expect(toolResult, containsPair('isError', true));
    });

    test('normalizes non-empty error string tool output as an error', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        jsonEncode(<String, dynamic>{'error': 'message'}),
      );

      expect(toolResult, containsPair('isError', true));
    });

    test('normalizes empty error string tool output as non-error', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        jsonEncode(<String, dynamic>{'error': ''}),
      );

      expect(toolResult, containsPair('isError', false));
    });

    test('normalizes non-JSON tool output as non-error', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        'plain text',
      );

      expect(toolResult, containsPair('output', 'plain text'));
      expect(toolResult, containsPair('isError', false));
    });

    test(
      'normalizes JSON array and primitive tool outputs as non-errors',
      () async {
        final arrayToolResult = await _submitSingleNormalizationToolResult(
          jsonEncode(<int>[1, 2, 3]),
        );
        final primitiveToolResult = await _submitSingleNormalizationToolResult(
          jsonEncode(42),
        );

        expect(arrayToolResult, containsPair('isError', false));
        expect(primitiveToolResult, containsPair('isError', false));
      },
    );

    test(
      'normalizes success true as non-error even with error fields',
      () async {
        final toolResult = await _submitSingleNormalizationToolResult(
          jsonEncode(<String, dynamic>{
            'success': true,
            'isError': true,
            'error': 'message',
          }),
        );

        expect(toolResult, containsPair('isError', false));
      },
    );

    test('normalizes success false as error even with isError false', () async {
      final toolResult = await _submitSingleNormalizationToolResult(
        jsonEncode(<String, dynamic>{'success': false, 'isError': false}),
      );

      expect(toolResult, containsPair('isError', true));
    });

    test(
      'cancellation before initial completed response ignores the late response',
      () async {
        void Function()? cancelQuery;
        final initialResponse = Completer<ResponseBody>();
        final adapter = _RecordingAdapter((_) {
          return initialResponse.future;
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        final query = started.service.sendQuery(
          'agent-1',
          'cancel before completed response',
          onCancel: (cancel) {
            cancelQuery = cancel;
            return () {};
          },
        );
        await Future<void>.delayed(Duration.zero);
        cancelQuery?.call();
        initialResponse.complete(
          _jsonResponse(200, <String, dynamic>{
            'status': 'completed',
            'text': 'late completed response',
          }),
        );

        await expectLater(
          query,
          throwsA(predicate((error) => error.toString().contains('cancelled'))),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test(
      'cancellation before initial requires_tool response ignores nested work',
      () async {
        void Function()? cancelQuery;
        final initialResponse = Completer<ResponseBody>();
        final probeTool = _CountingProbeTool('ignored');
        final adapter = _RecordingAdapter((_) {
          return initialResponse.future;
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
          toolbox: _TestToolbox(<Tool>[probeTool]),
        );
        addTearDown(started.dispose);

        final query = started.service.sendQuery(
          'agent-1',
          'cancel before requires tool response',
          onCancel: (cancel) {
            cancelQuery = cancel;
            return () {};
          },
        );
        await Future<void>.delayed(Duration.zero);
        cancelQuery?.call();
        initialResponse.complete(
          _jsonResponse(200, <String, dynamic>{
            'status': 'requires_tool',
            'toolCalls': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tc_late',
                'name': _CountingProbeTool.toolKeyName,
                'arguments': '{}',
              },
            ],
          }),
        );

        await expectLater(
          query,
          throwsA(predicate((error) => error.toString().contains('cancelled'))),
        );
        expect(adapter.requests, hasLength(1));
        expect(probeTool.executionCount, 0);
      },
    );

    test('does not submit cancellation as a normal tool error', () async {
      void Function()? cancelQuery;
      var requestCount = 0;
      final adapter = _RecordingAdapter((_) async {
        requestCount += 1;
        if (requestCount == 1) {
          return _jsonResponse(200, <String, dynamic>{
            'status': 'requires_tool',
            'toolCalls': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tc_cancel',
                'name': _CancellationProbeTool.toolKeyName,
                'arguments': '{}',
              },
            ],
          });
        }
        return _jsonResponse(200, <String, dynamic>{
          'status': 'completed',
          'text': '',
        });
      });
      final started = await _startService(
        adapter: adapter,
        voiceSessionId: 'vs_0123456789abcdef',
        toolbox: _TestToolbox(<Tool>[_CancellationProbeTool()]),
      );
      addTearDown(started.dispose);

      final query = started.service.sendQuery(
        'agent-1',
        'cancel',
        onCancel: (cancel) {
          cancelQuery = cancel;
          return () {};
        },
      );
      await Future<void>.delayed(Duration.zero);
      cancelQuery?.call();

      await expectLater(
        query,
        throwsA(predicate((error) => error.toString().contains('cancelled'))),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      'cancellation during continuation ignores the late completed response',
      () async {
        void Function()? cancelQuery;
        var requestCount = 0;
        final continuationResponse = Completer<ResponseBody>();
        final adapter = _RecordingAdapter((_) {
          requestCount += 1;
          if (requestCount == 1) {
            return Future<ResponseBody>.value(
              _jsonResponse(200, <String, dynamic>{
                'status': 'requires_tool',
                'toolCalls': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'tc_continue',
                    'name': 'get_current_time',
                    'arguments': '{}',
                  },
                ],
              }),
            );
          }
          return continuationResponse.future;
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
        );
        addTearDown(started.dispose);

        final query = started.service.sendQuery(
          'agent-1',
          'cancel during continuation',
          onCancel: (cancel) {
            cancelQuery = cancel;
            return () {};
          },
        );
        while (adapter.requests.length < 2) {
          await Future<void>.delayed(Duration.zero);
        }
        cancelQuery?.call();
        continuationResponse.complete(
          _jsonResponse(200, <String, dynamic>{
            'status': 'completed',
            'text': 'late continuation response',
          }),
        );

        await expectLater(
          query,
          throwsA(predicate((error) => error.toString().contains('cancelled'))),
        );
        expect(adapter.requests, hasLength(2));
      },
    );

    test(
      'duplicate tool call ids in one response are not executed twice',
      () async {
        var requestCount = 0;
        final probeTool = _CountingProbeTool('counted');
        final adapter = _RecordingAdapter((_) async {
          requestCount += 1;
          if (requestCount == 1) {
            return _jsonResponse(200, <String, dynamic>{
              'status': 'requires_tool',
              'toolCalls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'tc_duplicate',
                  'name': _CountingProbeTool.toolKeyName,
                  'arguments': '{}',
                },
                <String, dynamic>{
                  'id': 'tc_duplicate',
                  'name': _CountingProbeTool.toolKeyName,
                  'arguments': '{}',
                },
              ],
            });
          }
          return _jsonResponse(200, <String, dynamic>{
            'status': 'completed',
            'text': 'Duplicate handled once.',
          });
        });
        final started = await _startService(
          adapter: adapter,
          voiceSessionId: 'vs_0123456789abcdef',
          toolbox: _TestToolbox(<Tool>[probeTool]),
        );
        addTearDown(started.dispose);

        final text = await started.service.sendQuery('agent-1', 'duplicate');

        expect(text, 'Duplicate handled once.');
        expect(probeTool.executionCount, 1);
        expect(adapter.requests, hasLength(2));
        final toolResult = Map<String, dynamic>.from(
          adapter.requestJsonBodies[1]['toolResult'] as Map,
        );
        expect(toolResult, containsPair('toolCallId', 'tc_duplicate'));
      },
    );

    test('fails clearly on repeated already submitted tool call ids', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <String, dynamic>{
          'status': 'requires_tool',
          'toolCalls': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tc_repeat',
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
        started.service.sendQuery('agent-1', 'repeat'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('already submitted tool call id') &&
                error.toString().contains('tc_repeat'),
          ),
        ),
      );
      expect(adapter.requests, hasLength(2));
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
                'name': 'unknown_tool_for_error_path',
                'arguments': '{}',
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

Future<Map<String, dynamic>> _submitSingleNormalizationToolResult(
  String output,
) async {
  var requestCount = 0;
  final adapter = _RecordingAdapter((_) async {
    requestCount += 1;
    if (requestCount == 1) {
      return _jsonResponse(200, <String, dynamic>{
        'status': 'requires_tool',
        'toolCalls': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'tc_normalize',
            'name': _OutputProbeTool.toolKeyName,
            'arguments': '{}',
          },
        ],
      });
    }
    return _jsonResponse(200, <String, dynamic>{
      'status': 'completed',
      'text': 'Tool result accepted.',
    });
  });
  final started = await _startService(
    adapter: adapter,
    voiceSessionId: 'vs_0123456789abcdef',
    toolbox: _TestToolbox(<Tool>[_OutputProbeTool(output)]),
  );
  addTearDown(started.dispose);

  final text = await started.service.sendQuery('agent-1', 'normalize');

  expect(text, 'Tool result accepted.');
  expect(adapter.requests, hasLength(2));
  return Map<String, dynamic>.from(
    adapter.requestJsonBodies[1]['toolResult'] as Map,
  );
}

List<String> _toolSchemaNames(Map<String, dynamic> body) {
  final toolSchemas = body['toolSchemas'] as List<dynamic>;
  return toolSchemas
      .map((schema) => (schema as Map<String, dynamic>)['name'] as String)
      .toList(growable: false);
}

Future<_StartedTextAgentService> _startService({
  required HttpClientAdapter adapter,
  required String? voiceSessionId,
  Toolbox? toolbox,
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
    textAgentApi: CallTextAgentApi(textAgentService: service),
    toolbox: toolbox,
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

final class _TestToolbox extends Toolbox {
  final List<Tool> _tools;

  _TestToolbox(this._tools);

  @override
  List<Tool> create() {
    return _tools;
  }
}

final class _OutputProbeTool extends Tool {
  static const String toolKeyName = 'normalization_probe';
  final String _output;

  _OutputProbeTool(this._output);

  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'Normalization Probe',
    displayDescription: 'Returns configured test output.',
    categoryKey: 'test',
    iconKey: 'test',
    sourceKey: 'test',
    publishedBy: 'test',
    description: 'Returns configured test output.',
    parametersSchema: <String, dynamic>{},
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    return _output;
  }
}

final class _CountingProbeTool extends Tool {
  static const String toolKeyName = 'counting_probe';
  final String _output;
  int executionCount = 0;

  _CountingProbeTool(this._output);

  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'Counting Probe',
    displayDescription: 'Counts executions and returns configured output.',
    categoryKey: 'test',
    iconKey: 'test',
    sourceKey: 'test',
    publishedBy: 'test',
    description: 'Counts executions and returns configured output.',
    parametersSchema: <String, dynamic>{},
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    executionCount += 1;
    return _output;
  }
}

final class _CancellationProbeTool extends Tool {
  static const String toolKeyName = 'cancellation_probe';

  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'Cancellation Probe',
    displayDescription: 'Throws after cancellation.',
    categoryKey: 'test',
    iconKey: 'test',
    sourceKey: 'test',
    publishedBy: 'test',
    description: 'Throws after cancellation.',
    parametersSchema: <String, dynamic>{},
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final cancellation = ToolCancellation.current;
    final completer = Completer<void>();
    var wasCancelled = false;
    cancellation?.onCancel(() {
      wasCancelled = true;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    if (cancellation == null || cancellation.isCancelled) {
      throw StateError('cancelled');
    }
    await completer.future;
    if (wasCancelled) {
      throw StateError('cancelled');
    }
    throw StateError('unreachable');
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
