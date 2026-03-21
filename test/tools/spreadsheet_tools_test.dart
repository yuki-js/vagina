import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart';
import 'package:vagina/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart';

import 'tool_test_fakes.dart';

void main() {
  group('Spreadsheet tools', () {
    test('spreadsheet_add_rows appends rows for .v2d.json', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/data/sheet.v2d.json', '[{"id":1,"name":"A"}]');
      final tool = SpreadsheetAddRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetAddRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/sheet.v2d.json',
        'rows': [
          {'id': 2, 'name': 'B'}
        ],
      })) as Map<String, dynamic>;

      expect(result['success'], true);
      final parsed = TabularData.parse(
        fs.activeFiles['/data/sheet.v2d.json']!,
        '.v2d.json',
      );
      expect(parsed.rows.length, 2);
      expect(parsed.rows[1]['name'], 'B');
    });

    test('spreadsheet_add_rows accepts uppercase extension', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/data/sheet.V2D.JSON', '[{"id":1,"name":"A"}]');
      final tool = SpreadsheetAddRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetAddRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/sheet.V2D.JSON',
        'rows': [
          {'id': 2, 'name': 'B'}
        ],
      })) as Map<String, dynamic>;

      expect(result['success'], true);
    });

    test('spreadsheet_add_rows rejects non-tabular path', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/note.md', 'hello');
      final tool = SpreadsheetAddRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetAddRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/docs/note.md',
        'rows': [
          {'id': 1}
        ],
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('not a tabular type'));
    });

    test('spreadsheet_update_rows updates matched row', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/data/sheet.v2d.json', '[{"id":1,"name":"A"}]');
      final tool = SpreadsheetUpdateRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetUpdateRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/sheet.v2d.json',
        'updates': [
          {
            'where': {'column': 'id', 'value': 1},
            'set': {'name': 'Z'},
          }
        ],
      })) as Map<String, dynamic>;
      expect(result['success'], true);

      final parsed = TabularData.parse(
        fs.activeFiles['/data/sheet.v2d.json']!,
        '.v2d.json',
      );
      expect(parsed.rows.single['name'], 'Z');
    });

    test('spreadsheet_update_rows fails when active file missing', () async {
      final fs = ToolTestFilesystemApi();
      final tool = SpreadsheetUpdateRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetUpdateRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/missing.v2d.json',
        'updates': [
          {
            'where': {'column': 'id', 'value': 1},
            'set': {'name': 'X'},
          }
        ],
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('Active file not found'));
    });

    test('spreadsheet_update_rows rejects non-tabular path', () async {
      final fs = ToolTestFilesystemApi()..seedActiveFile('/docs/note.md', 'x');
      final tool = SpreadsheetUpdateRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetUpdateRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/docs/note.md',
        'updates': [
          {
            'where': {'column': 'id', 'value': 1},
            'set': {'name': 'X'},
          }
        ],
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('not a tabular type'));
    });

    test('spreadsheet_delete_rows removes indexed rows', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile(
          '/data/sheet.v2d.json',
          '[{"id":1,"name":"A"},{"id":2,"name":"B"}]',
        );
      final tool = SpreadsheetDeleteRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetDeleteRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/sheet.v2d.json',
        'rowIndices': [0],
      })) as Map<String, dynamic>;
      expect(result['success'], true);

      final parsed = TabularData.parse(
        fs.activeFiles['/data/sheet.v2d.json']!,
        '.v2d.json',
      );
      expect(parsed.rows.length, 1);
      expect(parsed.rows.single['id'], 2);
    });

    test('spreadsheet_delete_rows rejects non-tabular path', () async {
      final fs = ToolTestFilesystemApi()..seedActiveFile('/docs/note.md', 'x');
      final tool = SpreadsheetDeleteRowsTool();
      await tool.init(
        makeToolContext(
          toolKey: SpreadsheetDeleteRowsTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/docs/note.md',
        'rowIndices': [0],
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('not a tabular type'));
    });
  });
}
