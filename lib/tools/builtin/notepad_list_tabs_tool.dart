import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class NotepadListTabsTool implements Tool {
  static const String toolKeyName = 'notepad_list_tabs';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ノートパッド一覧',
        displayDescription: 'ノートパッドのタブ一覧を取得します',
        categoryKey: 'notepad',
        iconKey: 'list',
        sourceKey: 'builtin',
        description:
            'List all currently open artifact tabs. Returns metadata for each tab including id, title, mime type, and timestamps.',
        parametersSchema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      );

  @override
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final tabs = await context.notepadApi.listTabs();
    return jsonEncode({
      'success': true,
      'tabs': tabs,
      'count': tabs.length,
    });
  }
}
