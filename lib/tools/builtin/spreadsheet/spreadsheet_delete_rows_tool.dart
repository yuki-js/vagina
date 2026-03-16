import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

class SpreadsheetDeleteRowsTool extends Tool {
  static const String toolKeyName = 'spreadsheet_delete_rows';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'スプレッドシート行削除',
        displayDescription: 'スプレッドシートから行を削除します',
        categoryKey: 'document',
        iconKey: 'playlist_remove',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Delete rows from an active spreadsheet file. The file must be a tabular type '
            '(text/csv, application/vagina-2d+json, or application/vagina-2d+jsonl). '
            'Specify rows to remove by their 0-based indices.',
        activation: ToolActivation.forExtensions(kTabularDocumentExtensions),
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Path of the active spreadsheet file',
            },
            'rowIndices': {
              'type': 'array',
              'description': 'Array of 0-based row indices to delete',
              'items': {
                'type': 'integer',
              },
            },
          },
          'required': ['path', 'rowIndices'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final indicesRaw = args['rowIndices'] as List<dynamic>;

    if (!isPathSupportedByActivation(path, definition.activation)) {
      return jsonEncode({
        'success': false,
        'error': 'File "$path" is not a tabular type. '
            'Expected extension: .v2d.csv, .v2d.json, or .v2d.jsonl',
      });
    }

    final activeFile = await context.filesystemApi.getActiveFile(path);
    if (activeFile == null) {
      return jsonEncode({
        'success': false,
        'error': 'Active file not found: $path',
      });
    }

    final extension = normalizedExtensionFromPath(path);

    final content = activeFile['content'] as String? ?? '';

    try {
      final data = TabularData.parse(content, extension);

      final indices = indicesRaw.map((i) => (i as num).toInt()).toList();
      final updated = data.deleteRows(indices);
      final serialized = updated.serialize(extension);

      await context.filesystemApi.updateActiveFile(path, serialized);

      return jsonEncode({
        'success': true,
        'path': path,
        'deletedRows': indices.toSet().length,
        'remainingRows': updated.rows.length,
        'message': '${indices.toSet().length} row(s) deleted successfully',
      });
    } on TabularDataException catch (e) {
      return jsonEncode({
        'success': false,
        'error': e.message,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to delete rows: $e',
      });
    }
  }
}
