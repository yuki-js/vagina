import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsDeleteTool extends Tool {
  static const String toolKeyName = 'fs_delete';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ファイル削除',
        displayDescription: '仮想ファイルシステムから削除します',
        categoryKey: 'filesystem',
        iconKey: 'delete',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description: 'Delete a filesystem path.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Absolute filesystem path to delete.',
            },
          },
          'required': ['path'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;

    try {
      await context.filesystemApi.delete(path);
      return jsonEncode({
        'success': true,
        'path': path,
        'message': 'Deleted successfully.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to delete: $e',
      });
    }
  }
}
