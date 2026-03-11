import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

class SpreadsheetAddRowsTool extends Tool {
  static const String toolKeyName = 'spreadsheet_add_rows';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'スプレッドシート行追加',
        displayDescription: 'スプレッドシートに行を追加します',
        categoryKey: 'document',
        iconKey: 'playlist_add',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Add rows to an active spreadsheet file. The file must be a tabular type '
            '(text/csv, application/vagina-2d+json, or application/vagina-2d+jsonl). '
            'Each row must have exactly the same keys as the existing columns.',
        activation: ToolActivation.forExtensions(kTabularDocumentExtensions),
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Path of the active spreadsheet file',
            },
            'rows': {
              'type': 'array',
              'description':
                  'Array of row objects to append. Each object must have exactly the same keys as existing columns.',
              'items': {
                'type': 'object',
              },
            },
          },
          'required': ['path', 'rows'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final rowsRaw = args['rows'] as List<dynamic>;

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

    final mimeType = tabularMimeTypeFromPath(path);
    if (mimeType == null) {
      return jsonEncode({
        'success': false,
        'error': 'No tabular MIME mapping found for path: $path',
      });
    }

    final content = activeFile['content'] as String? ?? '';

    try {
      final data = TabularData.parse(content, mimeType);

      final newRows =
          rowsRaw.map((r) => Map<String, dynamic>.from(r as Map)).toList();

      final updated = data.addRows(newRows);
      final serialized = updated.serialize(mimeType);

      await context.filesystemApi.updateActiveFile(path, serialized);

      return jsonEncode({
        'success': true,
        'path': path,
        'addedRows': newRows.length,
        'totalRows': updated.rows.length,
        'message': '${newRows.length} row(s) added successfully',
      });
    } on TabularDataException catch (e) {
      return jsonEncode({
        'success': false,
        'error': e.message,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to add rows: $e',
      });
    }
  }
}
