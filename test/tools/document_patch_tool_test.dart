import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/apis/tool_storage_api.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/tools/builtin/document/document_patch_tool.dart';

class _FakeNotepadApi implements NotepadApi {
  final Map<String, Map<String, dynamic>> _tabs = {};

  void seedTab({
    required String id,
    required String content,
    String mimeType = 'text/markdown',
    String title = 't',
  }) {
    _tabs[id] = {
      'id': id,
      'title': title,
      'content': content,
      'mimeType': mimeType,
      'createdAt': DateTime(2020, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2020, 1, 1).toIso8601String(),
      'contentLength': content.length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listTabs() async {
    return _tabs.values.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getTab(String id) async {
    final tab = _tabs[id];
    if (tab == null) return null;
    return Map<String, dynamic>.from(tab);
  }

  @override
  Future<String> createTab({
    required String content,
    required String mimeType,
    String? title,
  }) async {
    final id = 'tab_${_tabs.length + 1}';
    seedTab(id: id, content: content, mimeType: mimeType, title: title ?? 't');
    return id;
  }

  @override
  Future<bool> updateTab(
    String id, {
    String? content,
    String? title,
    String? mimeType,
  }) async {
    final tab = _tabs[id];
    if (tab == null) return false;

    if (content != null) {
      tab['content'] = content;
      tab['contentLength'] = content.length;
    }
    if (title != null) {
      tab['title'] = title;
    }
    if (mimeType != null) {
      tab['mimeType'] = mimeType;
    }

    tab['updatedAt'] = DateTime(2020, 1, 2).toIso8601String();
    return true;
  }

  @override
  Future<bool> closeTab(String id) async {
    return _tabs.remove(id) != null;
  }
}

class _FakeCallApi implements CallApi {
  @override
  Future<bool> endCall({String? endContext}) async => true;
}

class _FakeTextAgentApi implements TextAgentApi {
  @override
  Future<List<Map<String, dynamic>>> listAgents() async => [];

  @override
  Future<String> sendQuery(String agentId, String prompt) async => '';
}

class _FakeToolStorageApi implements ToolStorageApi {
  final Map<String, dynamic> _store = {};

  @override
  Future<bool> save(String key, dynamic value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<dynamic> get(String key) async => _store[key];

  @override
  Future<Map<String, dynamic>> list() async => Map<String, dynamic>.from(_store);

  @override
  Future<bool> delete(String key) async => _store.remove(key) != null;

  @override
  Future<void> deleteAll() async => _store.clear();
}

ToolContext _makeContext(_FakeNotepadApi notepad) {
  return ToolContext(
    toolKey: DocumentPatchTool.toolKeyName,
    notepadApi: notepad,
    callApi: _FakeCallApi(),
    textAgentApi: _FakeTextAgentApi(),
    toolStorageApi: _FakeToolStorageApi(),
  );
}

void main() {
  group('DocumentPatchTool (structured patch)', () {
    test('replace succeeds and updates tab', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'Hello world\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      final resultJson = await tool.execute({
        'tabId': 't1',
        'patch': {
          'operations': [
            {
              'op': 'replace',
              'target': 'world',
              'newText': 'there',
            }
          ],
        },
      });

      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(result['appliedOperations'], 1);

      final updatedTab = await notepad.getTab('t1');
      expect(updatedTab!['content'], 'Hello there\n');
    });

    test('insert_after succeeds', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'A\nB\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await tool.execute({
        'tabId': 't1',
        'patch': {
          'operations': [
            {
              'op': 'insert_after',
              'target': 'A\n',
              'newText': 'X\n',
            }
          ],
        },
      });

      final updatedTab = await notepad.getTab('t1');
      expect(updatedTab!['content'], 'A\nX\nB\n');
    });

    test('delete succeeds', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'A\nB\nC\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await tool.execute({
        'tabId': 't1',
        'patch': {
          'operations': [
            {
              'op': 'delete',
              'target': 'B\n',
            }
          ],
        },
      });

      final updatedTab = await notepad.getTab('t1');
      expect(updatedTab!['content'], 'A\nC\n');
    });

    test('TARGET_NOT_FOUND throws and does not update tab', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'Hello\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await expectLater(
        () => tool.execute({
          'tabId': 't1',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': 'missing',
                'newText': 'x',
              }
            ],
          },
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('TARGET_NOT_FOUND') &&
                e.toString().contains('success') &&
                e.toString().contains('false'),
          ),
        ),
      );

      final updatedTab = await notepad.getTab('t1');
      expect(updatedTab!['content'], 'Hello\n');
    });

    test('partial failure throws and does not update tab', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'A\nB\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await expectLater(
        () => tool.execute({
          'tabId': 't1',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': 'A\n',
                'newText': 'AA\n',
              },
              {
                'op': 'replace',
                'target': 'MISSING\n',
                'newText': 'X\n',
              },
            ],
          },
        }),
        throwsA(
          predicate(
            (e) => e is Exception && e.toString().contains('TARGET_NOT_FOUND'),
          ),
        ),
      );

      final updatedTab = await notepad.getTab('t1');
      // Should remain unchanged because we do not persist partial results.
      expect(updatedTab!['content'], 'A\nB\n');
    });

    test('tabular mimeType throws', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(
        id: 't1',
        content: 'a,b\n1,2\n',
        mimeType: 'text/csv',
      );

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await expectLater(
        () => tool.execute({
          'tabId': 't1',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': '1,2',
                'newText': '3,4',
              }
            ],
          },
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('UNSUPPORTED_MIME_TYPE') &&
                e.toString().contains('success') &&
                e.toString().contains('false'),
          ),
        ),
      );
    });

    test('unified diff string patch throws UNSUPPORTED_PATCH_FORMAT', () async {
      final notepad = _FakeNotepadApi();
      notepad.seedTab(id: 't1', content: 'Hello\n');

      final tool = DocumentPatchTool();
      await tool.init(_makeContext(notepad));

      await expectLater(
        () => tool.execute({
          'tabId': 't1',
          'patch': '@@ -1 +1 @@\n-Hello\n+Hi\n',
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('UNSUPPORTED_PATCH_FORMAT') &&
                e.toString().contains('unified diff'),
          ),
        ),
      );
    });
  });
}
