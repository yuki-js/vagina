import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsCloseTool extends Tool {
  static const String toolKeyName = 'fs_close';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ファイルを閉じる',
        displayDescription: '作業中ファイルを保存して閉じます',
        categoryKey: 'filesystem',
        iconKey: 'close',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Persist active file content to filesystem and close the active file.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Absolute filesystem path to close.',
            },
          },
          'required': ['path'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;

    try {
      final active = await context.filesystemApi.getActiveFile(path);
      if (active == null) {
        return jsonEncode({
          'success': false,
          'error': 'Active file not found: $path',
        });
      }

      final content = active['content'] as String? ?? '';
      await context.filesystemApi.write(path, content);
      await context.filesystemApi.closeFile(path);

      return jsonEncode({
        'success': true,
        'path': path,
        'message': 'File saved and closed successfully.',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to close file: $e',
      });
    }
  }
}
