import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class NotepadGetMetadataTool extends Tool {
  static const String toolKeyName = 'notepad_get_metadata';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ノートパッド情報',
        displayDescription: 'ノートパッドの詳細情報を取得します',
        categoryKey: 'notepad',
        iconKey: 'info',
        sourceKey: 'builtin',
        description:
            'Get metadata of a specific artifact tab by its ID. Returns id, title, mime type, timestamps, and content length.',
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
      'metadata': tab,
    });
  }
}
