import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsOpenTool extends Tool {
  static const String toolKeyName = 'fs_open';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ファイルを開く',
        displayDescription: 'ファイルを開いて作業中ファイルにします',
        categoryKey: 'filesystem',
        iconKey: 'folder_open',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Open a persisted filesystem file into active runtime state by path.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Absolute filesystem path to open.',
            },
            'createIfMissing': {
              'type': 'boolean',
              'description':
                  'If true, create an empty file when the path does not exist.',
            },
          },
          'required': ['path'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final createIfMissing = (args['createIfMissing'] as bool?) ?? false;

    try {
      var file = await context.filesystemApi.read(path);
      if (file == null && createIfMissing) {
        await context.filesystemApi.write(path, '');
        file = {
          'path': path,
          'content': '',
        };
      }
      if (file == null) {
        return jsonEncode({
          'success': false,
          'error': 'File not found: $path',
        });
      }

      final content = file['content'] as String? ?? '';
      await context.filesystemApi.openFile(path, content);

      return jsonEncode({
        'success': true,
        'path': path,
        'message': 'File opened successfully.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to open file: $e',
      });
    }
  }
}
