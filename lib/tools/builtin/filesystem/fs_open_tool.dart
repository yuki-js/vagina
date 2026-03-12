import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/builtin/document/document_overwrite_tool.dart';
import 'package:vagina/tools/builtin/document/document_patch_tool.dart';
import 'package:vagina/tools/builtin/document/document_read_tool.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart';

final List<ToolDefinition> _pathBoundDefinitions = <ToolDefinition>[
  DocumentReadTool().definition,
  DocumentOverwriteTool().definition,
  DocumentPatchTool().definition,
  SpreadsheetAddRowsTool().definition,
  SpreadsheetUpdateRowsTool().definition,
  SpreadsheetDeleteRowsTool().definition,
];

List<String> _availableToolsForPath(String path) {
  final activeExtensions = <String>{normalizedExtensionFromPath(path)};
  final keys = _pathBoundDefinitions
      .where(
        (definition) =>
            definition.activation.isEnabledForExtensions(activeExtensions),
      )
      .map((definition) => definition.toolKey)
      .toSet()
      .toList()
    ..sort();
  return keys;
}

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
            'Open a persisted filesystem file into active runtime state by path. '
            'On success, returns available_tools for that path (path-bound applicability, not session-global tools).',
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
      final availableTools = _availableToolsForPath(path);

      return jsonEncode({
        'success': true,
        'path': path,
        'available_tools': availableTools,
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
