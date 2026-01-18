import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class NotepadGetMetadataTool implements Tool {
  static const String toolKeyName = 'notepad_get_metadata';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

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
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final tabId = args['tabId'] as String;
    final metadata = context.notepadService.getTabMetadata(tabId);

    if (metadata == null) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    return jsonEncode({
      'success': true,
      'metadata': metadata,
    });
  }
}
