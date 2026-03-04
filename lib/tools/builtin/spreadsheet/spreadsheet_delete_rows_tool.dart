import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

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
            'Delete rows from an existing spreadsheet tab. The tab must have a tabular MIME type '
            '(text/csv, application/vagina-2d+json, or application/vagina-2d+jsonl). '
            'Specify rows to remove by their 0-based indices.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the spreadsheet tab to delete rows from',
            },
            'rowIndices': {
              'type': 'array',
              'description': 'Array of 0-based row indices to delete',
              'items': {
                'type': 'integer',
              },
            },
          },
          'required': ['tabId', 'rowIndices'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String;
    final indicesRaw = args['rowIndices'] as List<dynamic>;

    final tab = await context.notepadApi.getTab(tabId);
    if (tab == null) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    final mimeType = tab['mimeType'] as String;
    switch (mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        break;
      default:
        return jsonEncode({
          'success': false,
          'error': 'Tab "$tabId" is not a tabular type (mimeType: $mimeType). '
              'Expected one of: text/csv, application/vagina-2d+json, application/vagina-2d+jsonl',
        });
    }

    final content = tab['content'] as String;

    try {
      final data = TabularData.parse(content, mimeType);

      final indices = indicesRaw.map((i) => (i as num).toInt()).toList();
      final updated = data.deleteRows(indices);
      final serialized = updated.serialize(mimeType);

      final success = await context.notepadApi.updateTab(
        tabId,
        content: serialized,
      );

      if (!success) {
        return jsonEncode({
          'success': false,
          'error': 'Failed to update tab after deleting rows.',
        });
      }

      return jsonEncode({
        'success': true,
        'tabId': tabId,
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
