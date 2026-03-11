import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsActiveFilesTool extends Tool {
  static const String toolKeyName = 'fs_active_files';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: '作業中ファイル一覧',
        displayDescription: '現在開いているファイルを表示します',
        categoryKey: 'filesystem',
        iconKey: 'list',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'List currently active filesystem files in the runtime open set.',
        parametersSchema: {
          'type': 'object',
          'properties': {},
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final activeFiles = await context.filesystemApi.listActiveFiles();
      final paths = activeFiles
          .map((entry) => entry['path'])
          .whereType<String>()
          .toList()
        ..sort();

      return jsonEncode({
        'success': true,
        'count': paths.length,
        'paths': paths,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to list active files: $e',
      });
    }
  }
}
