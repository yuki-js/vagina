import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/tools/builtin/document/document_overwrite_tool.dart';
import 'package:vagina/tools/builtin/document/document_read_tool.dart';

import 'tool_test_fakes.dart';

void main() {
  group('Document tools', () {
    test('document_read returns active content', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/a.md', '# Hello');
      final tool = DocumentReadTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentReadTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], true);
      expect(result['content'], '# Hello');
    });

    test('document_read fails when file is not active', () async {
      final fs = ToolTestFilesystemApi();
      final tool = DocumentReadTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentReadTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('Active file not found'));
    });

    test('document_read rejects unsupported extension', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/file.pdf', 'binary-ish');
      final tool = DocumentReadTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentReadTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/file.pdf'}))
          as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('Unsupported file type'));
    });

    test('document_overwrite updates active content', () async {
      final fs = ToolTestFilesystemApi()..seedActiveFile('/docs/a.md', 'old');
      final tool = DocumentOverwriteTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentOverwriteTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/docs/a.md',
        'content': 'new',
      })) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.activeFiles['/docs/a.md'], 'new');
      expect(fs.activeUpdates, hasLength(1));
    });

    test('document_overwrite stringifies structured content', () async {
      final fs = ToolTestFilesystemApi()..seedActiveFile('/docs/data.md', '{}');
      final tool = DocumentOverwriteTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentOverwriteTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      await tool.execute({
        'path': '/docs/data.md',
        'content': {
          'k': 'v',
          'n': 1,
        },
      });

      expect(fs.activeFiles['/docs/data.md'], '{"k":"v","n":1}');
    });

    test('document_overwrite fails when file is not active', () async {
      final fs = ToolTestFilesystemApi();
      final tool = DocumentOverwriteTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentOverwriteTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/docs/a.md',
        'content': 'x',
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('Active file not found'));
    });

    test('document_overwrite rejects non-text extension', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/data/table.v2d.json', '[{\"id\":1}]');
      final tool = DocumentOverwriteTool();
      await tool.init(
        makeToolContext(
          toolKey: DocumentOverwriteTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'path': '/data/table.v2d.json',
        'content': 'x',
      })) as Map<String, dynamic>;
      expect(result['success'], false);
      expect(result['error'], contains('Unsupported file type'));
    });
  });
}
