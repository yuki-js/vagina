import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class SpreadsheetUpdateRowsTool extends Tool {
  static const String toolKeyName = 'spreadsheet_update_rows';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'スプレッドシート行更新',
        displayDescription: 'スプレッドシートの行を条件検索して更新します',
        categoryKey: 'document',
        iconKey: 'edit',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Update rows in an existing spreadsheet tab using VLOOKUP-style search. The tab must have a tabular MIME type '
            '(text/csv, application/vagina-2d+json, or application/vagina-2d+jsonl). '
            'Each update specifies a "where" condition (column and value to match) and a "set" object with values to update. '
            'By default updates only the first matching row; set "updateAll": true to update all matches.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the spreadsheet tab to update',
            },
            'updates': {
              'type': 'array',
              'description':
                  'Array of update operations. Each operation finds rows using a "where" condition and updates them with "set" values.',
              'items': {
                'type': 'object',
                'properties': {
                  'where': {
                    'type': 'object',
                    'description':
                        'Condition to find the row(s). Specify "column" (name) and "value" to match.',
                    'properties': {
                      'column': {
                        'type': 'string',
                        'description': 'Column name to search in',
                      },
                      'value': {
                        'description':
                            'Value to match (string, number, bool, or null)',
                      },
                    },
                    'required': ['column', 'value'],
                  },
                  'set': {
                    'type': 'object',
                    'description':
                        'Column-value pairs to update in the matching row(s)',
                  },
                  'updateAll': {
                    'type': 'boolean',
                    'description':
                        'If true, update all matching rows. If false or omitted, update only the first match.',
                  },
                },
                'required': ['where', 'set'],
              },
            },
          },
          'required': ['tabId', 'updates'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String;
    final updatesRaw = args['updates'] as List<dynamic>;

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

      final updates =
          updatesRaw.map((u) => Map<String, dynamic>.from(u as Map)).toList();

      final updated = data.updateRows(updates);
      final serialized = updated.serialize(mimeType);

      final success = await context.notepadApi.updateTab(
        tabId,
        content: serialized,
      );

      if (!success) {
        return jsonEncode({
          'success': false,
          'error': 'Failed to update tab after row updates.',
        });
      }

      return jsonEncode({
        'success': true,
        'tabId': tabId,
        'updatedOperations': updates.length,
        'message':
            '${updates.length} update operation(s) completed successfully',
      });
    } on TabularDataException catch (e) {
      return jsonEncode({
        'success': false,
        'error': e.message,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to update rows: $e',
      });
    }
  }
}
