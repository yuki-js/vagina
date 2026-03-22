import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/services/call_control_api.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/tool_runner.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';

void main() {
  group('ToolRunner', () {
    late ToolRunner runner;
    late _FakeVirtualFilesystemRepository filesystemRepository;
    late _TestCallService callService;

    setUp(() {
      filesystemRepository = _FakeVirtualFilesystemRepository();
      callService = _TestCallService();
      runner = ToolRunner(
        filesystemApi: _FakeFilesystemApi(filesystemRepository),
        callApi: CallControlApi(callService: callService),
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

    test('executes fs_list with fake filesystem repository', () async {
      filesystemRepository.files['/test.txt'] =
          const VirtualFile(path: '/test.txt', content: 'content');
      filesystemRepository.files['/data.csv'] =
          const VirtualFile(path: '/data.csv', content: 'data');

      await runner.start(enabledToolKeys: const {'fs_list'});

      final output = await runner.execute(
        'fs_list',
        jsonEncode({'path': '/'}),
      );
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['entries'], containsAll(['test.txt', 'data.csv']));
    });

    test('executes end_call through CallControlApi', () async {
      await runner.start(enabledToolKeys: const {'end_call'});

      final output = await runner.execute(
        'end_call',
        jsonEncode({'end_context': 'test'}),
      );
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      await pumpEventQueue();

      expect(decoded['success'], isTrue);
      expect(decoded['ended'], isTrue);
      expect(callService.endCallCalled, isTrue);
      expect(callService.lastEndContext, equals('test'));
    });
  });
}

final class _FakeVirtualFilesystemRepository
    implements VirtualFilesystemRepository {
  final Map<String, VirtualFile> files = <String, VirtualFile>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async => files[path];

  @override
  Future<void> write(VirtualFile file) async {
    files[file.path] = file;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final file = files.remove(fromPath);
    if (file != null) {
      files[toPath] = VirtualFile(path: toPath, content: file.content);
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return files.keys
        .where((key) => key.startsWith(path))
        .map((key) => key.substring(1))
        .toList();
  }
}

final class _FakeFilesystemApi implements FilesystemApi {
  final VirtualFilesystemRepository _repository;
  final Map<String, String> _activeFiles = <String, String>{};

  _FakeFilesystemApi(this._repository);

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final file = await _repository.read(path);
    if (file == null) {
      return null;
    }
    return <String, dynamic>{
      'path': file.path,
      'content': file.content,
    };
  }

  @override
  Future<void> write(String path, String content) {
    return _repository.write(VirtualFile(path: path, content: content));
  }

  @override
  Future<void> delete(String path) {
    _activeFiles.remove(path);
    return _repository.delete(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final activeContent = _activeFiles.remove(fromPath);
    if (activeContent != null) {
      _activeFiles[toPath] = activeContent;
    }
    await _repository.move(fromPath, toPath);
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) {
    return _repository.list(path, recursive: recursive);
  }

  @override
  Future<void> openFile(String path, String content) async {
    _activeFiles[path] = content;
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final content = _activeFiles[path];
    if (content == null) {
      return null;
    }
    return <String, dynamic>{'path': path, 'content': content};
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    _activeFiles[path] = content;
  }

  @override
  Future<void> closeFile(String path) async {
    _activeFiles.remove(path);
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    return _activeFiles.entries
        .map(
          (entry) => <String, dynamic>{
            'path': entry.key,
            'content': entry.value,
          },
        )
        .toList(growable: false);
  }
}

final class _TestCallService extends CallService {
  bool endCallCalled = false;
  String? lastEndContext;

  _TestCallService()
      : super(
          filesystemRepository: _FakeVirtualFilesystemRepository(),
        ) {
    setVoiceAgent(
      const VoiceAgentInfo(
        id: 'voice-agent',
        name: 'Test Agent',
        description: 'Tool runner test agent',
        voice: 'alloy',
        prompt: 'Be brief.',
        apiConfig: HostedVoiceAgentApiConfig(modelId: 'gpt-realtime-test'),
      ),
    );
  }

  @override
  Future<void> endCall({String? endContext}) async {
    endCallCalled = true;
    lastEndContext = endContext;
  }
}
