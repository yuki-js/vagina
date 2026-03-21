import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/tool_runner.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

void main() {
  group('ToolRunner', () {
    late ToolRunner runner;

    setUp(() {
      runner = ToolRunner(
        filesystemApi: _FakeFilesystemApi(),
        callApi: _FakeCallApi(),
        textAgentApi: _FakeTextAgentApi(),
      );
    });

    tearDown(() async {
      await runner.dispose();
    });

    test('filters enabled tool definitions by configured keys', () async {
      await runner.start(
        enabledToolKeys: const <String>{'calculator'},
      );

      final keys = runner.enabledDefinitions
          .map((definition) => definition.toolKey)
          .toList(growable: false);

      expect(keys, unorderedEquals(const <String>['calculator']));
    });

    test('executes calculator tool with JSON arguments', () async {
      await runner.start(
        enabledToolKeys: const <String>{'calculator'},
      );

      final output = await runner.execute(
        'calculator',
        jsonEncode({'expression': '2 + 3 * 4'}),
      );
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['expression'], equals('2 + 3 * 4'));
      expect(decoded['result'], equals(14.0));
    });

    test('returns an error payload for unknown tools', () async {
      await runner.start(
        enabledToolKeys: const <String>{'calculator'},
      );

      final output = await runner.execute('missing_tool', '{}');
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['error'], equals('Unknown tool: missing_tool'));
    });

    test('returns an error payload for disabled tools', () async {
      await runner.start(
        enabledToolKeys: const <String>{'calculator'},
      );

      final output = await runner.execute('end_call', '{}');
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(
        decoded['error'],
        equals('Tool is not enabled for this session: end_call'),
      );
    });

    test('executes fs_list with fake filesystem', () async {
      final fakeFs = _FakeFilesystemApi();
      fakeFs.files['/test.txt'] = 'content';
      fakeFs.files['/data.csv'] = 'data';

      final runnerWithFs = ToolRunner(
        filesystemApi: fakeFs,
        callApi: _FakeCallApi(),
        textAgentApi: _FakeTextAgentApi(),
      );

      await runnerWithFs.start(enabledToolKeys: const {'fs_list'});

      final output = await runnerWithFs.execute(
        'fs_list',
        jsonEncode({'path': '/'}),
      );
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['entries'], containsAll(['test.txt', 'data.csv']));

      await runnerWithFs.dispose();
    });

    test('executes end_call through CallApi', () async {
      final fakeCallApi = _FakeCallApi();
      final runnerWithCall = ToolRunner(
        filesystemApi: _FakeFilesystemApi(),
        callApi: fakeCallApi,
        textAgentApi: _FakeTextAgentApi(),
      );

      await runnerWithCall.start(enabledToolKeys: const {'end_call'});

      final output = await runnerWithCall.execute(
        'end_call',
        jsonEncode({'end_context': 'test'}),
      );
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['ended'], isTrue);
      expect(fakeCallApi.endCallCalled, isTrue);
      expect(fakeCallApi.lastEndContext, equals('test'));

      await runnerWithCall.dispose();
    });
  });
}

final class _FakeFilesystemApi implements FilesystemApi {
  final Map<String, String> files = {};

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final content = files[path];
    if (content == null) return null;
    return {'path': path, 'content': content};
  }

  @override
  Future<void> write(String path, String content) async {
    files[path] = content;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final content = files.remove(fromPath);
    if (content != null) {
      files[toPath] = content;
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return files.keys
        .where((key) => key.startsWith(path))
        .map((key) => key.substring(1))
        .toList();
  }

  @override
  Future<void> openFile(String path, String content) async {
    files[path] = content;
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final content = files[path];
    if (content == null) return null;
    return {'path': path, 'content': content};
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    files[path] = content;
  }

  @override
  Future<void> closeFile(String path) async {
    files.remove(path);
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    return files.entries
        .map((e) => {'path': e.key, 'content': e.value})
        .toList();
  }
}

final class _FakeCallApi implements CallApi {
  bool endCallCalled = false;
  String? lastEndContext;

  @override
  Future<bool> endCall({String? endContext}) async {
    endCallCalled = true;
    lastEndContext = endContext;
    return true;
  }
}

final class _FakeTextAgentApi implements TextAgentApi {
  @override
  Future<String> sendQuery(String agentId, String prompt) async {
    return jsonEncode({'error': 'Fake text agent not implemented'});
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return const [];
  }
}
