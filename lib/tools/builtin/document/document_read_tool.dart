import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

class DocumentReadTool extends Tool {
  static const String toolKeyName = 'document_read';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント表示',
        displayDescription: 'ドキュメントの内容を表示します',
        categoryKey: 'document',
        iconKey: 'visibility',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description: 'Read the content of an active filesystem file by path.',
        activation: ToolActivation.forExtensions(kReadableDocumentExtensions),
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Absolute path of the active file to read',
            },
          },
          'required': ['path'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;

    if (!isPathSupportedByActivation(path, definition.activation)) {
      return jsonEncode({
        'success': false,
        'error': 'Unsupported file type for document_read: $path',
      });
    }

    final file = await context.filesystemApi.getActiveFile(path);
    if (file == null) {
      return jsonEncode({
        'success': false,
        'error': 'Active file not found: $path',
      });
    }

    return jsonEncode({
      'success': true,
      'path': path,
      'content': file['content'],
    });
  }
}
