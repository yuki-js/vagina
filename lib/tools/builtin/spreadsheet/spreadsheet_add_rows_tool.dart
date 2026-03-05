import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

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
            'Add rows to an existing spreadsheet tab. The tab must have a tabular MIME type '
            '(text/csv, application/vagina-2d+json, or application/vagina-2d+jsonl). '
            'Each row must have exactly the same keys as the existing columns.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the spreadsheet tab to add rows to',
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
          'required': ['tabId', 'rows'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String;
    final rowsRaw = args['rows'] as List<dynamic>;

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

      final newRows =
          rowsRaw.map((r) => Map<String, dynamic>.from(r as Map)).toList();

      final updated = data.addRows(newRows);
      final serialized = updated.serialize(mimeType);

      final success = await context.notepadApi.updateTab(
        tabId,
        content: serialized,
      );

      if (!success) {
        return jsonEncode({
          'success': false,
          'error': 'Failed to update tab after adding rows.',
        });
      }

      return jsonEncode({
        'success': true,
        'tabId': tabId,
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
