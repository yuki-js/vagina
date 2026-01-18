import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class NotepadCloseTabTool implements Tool {
  static const String toolKeyName = 'notepad_close_tab';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ノートパッド閉じる',
        displayDescription: 'ノートパッドのタブを閉じます',
        categoryKey: 'notepad',
        iconKey: 'close',
        sourceKey: 'builtin',
        description: 'Close an artifact tab by its ID.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'The unique identifier of the tab to close',
            },
          },
          'required': ['tabId'],
        },
      );

  @override
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final tabId = args['tabId'] as String;
    final success = context.notepadService.closeTab(tabId);

    if (!success) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    return jsonEncode({
      'success': true,
      'message': 'Tab closed successfully',
    });
  }
}
