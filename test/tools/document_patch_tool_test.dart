import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/tools/builtin/document/document_patch_tool.dart';

import 'tool_test_fakes.dart';

void main() {
  group('DocumentPatchTool (structured patch)', () {
    test('replace succeeds and updates file', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'Hello world\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      final resultJson = await tool.execute({
        'path': '/docs/t1.md',
        'patch': {
          'operations': [
            {
              'op': 'replace',
              'target': 'world',
              'newText': 'there',
            }
          ],
        },
      });

      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(result['appliedOperations'], 1);
      expect(filesystem.activeFiles['/docs/t1.md'], 'Hello there\n');
    });

    test('insert_after succeeds', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'A\nB\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await tool.execute({
        'path': '/docs/t1.md',
        'patch': {
          'operations': [
            {
              'op': 'insert_after',
              'target': 'A\n',
              'newText': 'X\n',
            }
          ],
        },
      });

      expect(filesystem.activeFiles['/docs/t1.md'], 'A\nX\nB\n');
    });

    test('delete succeeds', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'A\nB\nC\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await tool.execute({
        'path': '/docs/t1.md',
        'patch': {
          'operations': [
            {
              'op': 'delete',
              'target': 'B\n',
            }
          ],
        },
      });

      expect(filesystem.activeFiles['/docs/t1.md'], 'A\nC\n');
    });

    test('TARGET_NOT_FOUND throws and does not update file', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'Hello\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await expectLater(
        () => tool.execute({
          'path': '/docs/t1.md',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': 'missing',
                'newText': 'x',
              }
            ],
          },
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('TARGET_NOT_FOUND') &&
                e.toString().contains('success') &&
                e.toString().contains('false'),
          ),
        ),
      );

      expect(filesystem.activeFiles['/docs/t1.md'], 'Hello\n');
    });

    test('partial failure throws and does not update file', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'A\nB\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await expectLater(
        () => tool.execute({
          'path': '/docs/t1.md',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': 'A\n',
                'newText': 'AA\n',
              },
              {
                'op': 'replace',
                'target': 'MISSING\n',
                'newText': 'X\n',
              },
            ],
          },
        }),
        throwsA(
          predicate(
            (e) => e is Exception && e.toString().contains('TARGET_NOT_FOUND'),
          ),
        ),
      );

      expect(filesystem.activeFiles['/docs/t1.md'], 'A\nB\n');
    });

    test('tabular file path throws', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/data/table.v2d.csv', 'a,b\n1,2\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await expectLater(
        () => tool.execute({
          'path': '/data/table.v2d.csv',
          'patch': {
            'operations': [
              {
                'op': 'replace',
                'target': '1,2',
                'newText': '3,4',
              }
            ],
          },
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('UNSUPPORTED_MIME_TYPE') &&
                e.toString().contains('success') &&
                e.toString().contains('false'),
          ),
        ),
      );
    });

    test('unified diff string patch throws UNSUPPORTED_PATCH_FORMAT', () async {
      final filesystem = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/t1.md', 'Hello\n');

      final tool = DocumentPatchTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentPatchTool.toolKeyName,
          filesystemApi: filesystem,
        ),
      );

      await expectLater(
        () => tool.execute({
          'path': '/docs/t1.md',
          'patch': '@@ -1 +1 @@\n-Hello\n+Hi\n',
        }),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('UNSUPPORTED_PATCH_FORMAT') &&
                e.toString().contains('unified diff'),
          ),
        ),
      );
    });
  });
}
