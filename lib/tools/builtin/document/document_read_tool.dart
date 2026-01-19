import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class DocumentReadTool implements Tool {
  static const String toolKeyName = 'document_read';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント表示',
        displayDescription: 'ドキュメントの内容を表示します',
        categoryKey: 'document',
        iconKey: 'visibility',
        sourceKey: 'builtin',
        description:
            'Read the content of a document from an artifact tab. This returns the current content which may include modifications made by the user.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the tab containing the document to read',
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

    final tab = await context.notepadApi.getTab(tabId);
    if (tab == null) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    return jsonEncode({
      'success': true,
      'tabId': tabId,
      'content': tab['content'],
      'mime': tab['mimeType'],
      'title': tab['title'],
    });
  }
}
