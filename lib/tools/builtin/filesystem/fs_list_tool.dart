import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class FsListTool extends Tool {
  static const String toolKeyName = 'fs_list';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ファイル一覧',
        displayDescription: '仮想ファイルシステムの一覧を表示します',
        categoryKey: 'filesystem',
        iconKey: 'folder',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'List files under a virtual filesystem path. Returns child entries.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Directory path to list (default: /).',
            },
            'recursive': {
              'type': 'boolean',
              'description': 'If true, list recursively.',
            },
          },
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = (args['path'] as String?) ?? '/';
    final recursive = (args['recursive'] as bool?) ?? false;

    try {
      final entries = await context.filesystemApi.list(
        path,
        recursive: recursive,
      );
      return jsonEncode({
        'success': true,
        'path': path,
        'recursive': recursive,
        'entries': entries,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to list filesystem: $e',
      });
    }
  }
}
