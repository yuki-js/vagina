import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/tools/builtin/text_agent/get_last_text_agent_response_tool.dart';
import 'package:vagina/tools/builtin/text_agent/query_text_agent_tool.dart';

void main() {
  group('QueryTextAgentTool user-facing cancellation contract', () {
    test(
      // Contract: after the user interrupts a parent turn while say_hello_to_agent
      // is waiting on a sub-agent:
      // - the sub-agent request receives the same cancellation signal;
      // - the tool stops instead of turning cancellation into a normal result;
      // - the abandoned parent turn is not pulled forward by stale sub-agent work.
      'hands parent cancellation to the sub-agent request',
      () async {
        final cancellation = ToolCancellation();
        var subAgentCancelCount = 0;
        final subAgentResponse = Completer<String>();
        final tool = QueryTextAgentTool();
        await tool.init(
          ToolContext(
            toolKey: QueryTextAgentTool.toolKeyName,
            filesystemApi: _NoopFilesystemApi(),
            callApi: _NoopCallApi(),
            textAgentApi: _FakeTextAgentApi(
              onSendQuery: ({attachLastUserImage = false, onCancel}) {
                onCancel?.call(() {
                  subAgentCancelCount += 1;
                  subAgentResponse.completeError(
                    StateError('sub-agent request cancelled'),
                  );
                });
                return subAgentResponse.future;
              },
            ),
          ),
        );

        final execution = ToolCancellation.run(
          cancellation,
          () => tool.execute(<String, dynamic>{
            'agent_id': 'agent-1',
            'prompt': 'delegate this',
          }),
        );
        await _flushAsyncWork();
        cancellation.cancel();

        await expectLater(execution, throwsA(anything));
        expect(subAgentCancelCount, 1);
      },
    );

    test('throws argument errors for missing or invalid parameters', () async {
      final tool = QueryTextAgentTool();
      await tool.init(
        ToolContext(
          toolKey: QueryTextAgentTool.toolKeyName,
          filesystemApi: _NoopFilesystemApi(),
          callApi: _NoopCallApi(),
          textAgentApi: _FakeTextAgentApi(
            onSendQuery: ({attachLastUserImage = false, onCancel}) =>
                Future<String>.value('unused'),
          ),
        ),
      );

      await expectLater(
        tool.execute(<String, dynamic>{'prompt': 'hello'}),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        tool.execute(<String, dynamic>{'agent_id': 42, 'prompt': 'hello'}),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        tool.execute(<String, dynamic>{'agent_id': 'agent-1'}),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        tool.execute(<String, dynamic>{'agent_id': 'agent-1', 'prompt': 42}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'passes attach_last_user_image through to the text agent API',
      () async {
        var observedAttachLastUserImage = false;
        final tool = QueryTextAgentTool();
        await tool.init(
          ToolContext(
            toolKey: QueryTextAgentTool.toolKeyName,
            filesystemApi: _NoopFilesystemApi(),
            callApi: _NoopCallApi(),
            textAgentApi: _FakeTextAgentApi(
              onSendQuery: ({attachLastUserImage = false, onCancel}) {
                observedAttachLastUserImage = attachLastUserImage;
                return Future<String>.value('ok');
              },
            ),
          ),
        );

        final output = await tool.execute(<String, dynamic>{
          'agent_id': 'agent-1',
          'prompt': 'inspect image',
          'attach_last_user_image': true,
        });

        expect(output, contains('ok'));
        expect(observedAttachLastUserImage, isTrue);
      },
    );

    test('switches long-running query to async result retrieval', () async {
      final subAgentResponse = Completer<String>();
      final textAgentApi = _FakeTextAgentApi(
        onSendQuery: ({attachLastUserImage = false, onCancel}) {
          return subAgentResponse.future;
        },
      );
      final queryTool = QueryTextAgentTool(asyncFallbackDelay: Duration.zero);
      await queryTool.init(
        ToolContext(
          toolKey: QueryTextAgentTool.toolKeyName,
          filesystemApi: _NoopFilesystemApi(),
          callApi: _NoopCallApi(),
          textAgentApi: textAgentApi,
        ),
      );

      final initialOutput =
          jsonDecode(
                await queryTool.execute(<String, dynamic>{
                  'agent_id': 'agent-1',
                  'prompt': 'slow research',
                }),
              )
              as Map<String, dynamic>;
      expect(initialOutput['async'], isTrue);
      expect(initialOutput['status'], 'pending');

      final getTool = GetLastTextAgentResponseTool();
      await getTool.init(
        ToolContext(
          toolKey: GetLastTextAgentResponseTool.toolKeyName,
          filesystemApi: _NoopFilesystemApi(),
          callApi: _NoopCallApi(),
          textAgentApi: textAgentApi,
        ),
      );
      var lastOutput =
          jsonDecode(await getTool.execute(<String, dynamic>{}))
              as Map<String, dynamic>;
      expect(lastOutput['status'], 'pending');

      subAgentResponse.complete('done later');
      await _flushAsyncWork();

      lastOutput =
          jsonDecode(await getTool.execute(<String, dynamic>{}))
              as Map<String, dynamic>;
      expect(lastOutput['status'], 'completed');
      expect(lastOutput['text'], 'done later');
    });

    test(
      'throws text agent query failures instead of returning failure JSON',
      () async {
        final tool = QueryTextAgentTool();
        await tool.init(
          ToolContext(
            toolKey: QueryTextAgentTool.toolKeyName,
            filesystemApi: _NoopFilesystemApi(),
            callApi: _NoopCallApi(),
            textAgentApi: _FakeTextAgentApi(
              onSendQuery: ({attachLastUserImage = false, onCancel}) =>
                  Future<String>.error(
                    Exception(
                      'Text agent query request failed (409): active voice session ended',
                    ),
                  ),
            ),
          ),
        );

        await expectLater(
          tool.execute(<String, dynamic>{
            'agent_id': 'agent-1',
            'prompt': 'delegate this',
          }),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('active voice session ended'),
            ),
          ),
        );
      },
    );
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakeTextAgentApi implements TextAgentApi {
  final Future<String> Function({
    bool attachLastUserImage,
    void Function() Function(void Function())? onCancel,
  })
  onSendQuery;

  Map<String, dynamic> _lastAsyncQueryResult = const <String, dynamic>{
    'status': 'none',
  };

  _FakeTextAgentApi({required this.onSendQuery});

  @override
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    bool attachLastUserImage = false,
    void Function() Function(void Function())? onCancel,
  }) {
    return onSendQuery(
      attachLastUserImage: attachLastUserImage,
      onCancel: onCancel,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<void> setLastAsyncQueryResult(Map<String, dynamic> result) async {
    _lastAsyncQueryResult = Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> getLastAsyncQueryResult() async {
    return Map<String, dynamic>.from(_lastAsyncQueryResult);
  }
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
