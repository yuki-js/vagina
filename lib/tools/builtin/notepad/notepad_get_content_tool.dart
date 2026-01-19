import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class NotepadGetContentTool extends Tool {
  static const String toolKeyName = 'notepad_get_content';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ノートパッド読取',
        displayDescription: 'ノートパッドの内容を読み取ります',
        categoryKey: 'notepad',
        iconKey: 'article',
        sourceKey: 'builtin',
        description: 'Get the content of a specific artifact tab by its ID.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'The unique identifier of the tab',
            },
          },
          'required': ['tabId'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String;
    final tab = await context.notepadApi.getTab(tabId);

    if (tab == null) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    return jsonEncode({
      'success': true,
      'content': tab['content'],
      'mimeType': tab['mimeType'],
    });
  }
}
