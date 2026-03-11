import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsMoveTool extends Tool {
  static const String toolKeyName = 'fs_move';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ファイル移動',
        displayDescription: 'ファイルを移動または改名します',
        categoryKey: 'filesystem',
        iconKey: 'drive_file_move',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Move or rename a filesystem file from one path to another.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'fromPath': {
              'type': 'string',
              'description': 'Source absolute path.',
            },
            'toPath': {
              'type': 'string',
              'description': 'Destination absolute path.',
            },
          },
          'required': ['fromPath', 'toPath'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final fromPath = args['fromPath'] as String;
    final toPath = args['toPath'] as String;

    try {
      await context.filesystemApi.move(fromPath, toPath);
      return jsonEncode({
        'success': true,
        'fromPath': fromPath,
        'toPath': toPath,
        'message': 'Moved successfully.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to move: $e',
      });
    }
  }
}
