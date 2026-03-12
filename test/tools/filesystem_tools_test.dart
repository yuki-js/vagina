import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/tools/builtin/filesystem/fs_active_files_tool.dart';
import 'package:vagina/tools/builtin/filesystem/fs_close_tool.dart';
import 'package:vagina/tools/builtin/filesystem/fs_delete_tool.dart';
import 'package:vagina/tools/builtin/filesystem/fs_list_tool.dart';
import 'package:vagina/tools/builtin/filesystem/fs_move_tool.dart';
import 'package:vagina/tools/builtin/filesystem/fs_open_tool.dart';

import 'tool_test_fakes.dart';

void main() {
  group('Filesystem tools', () {
    test('fs_open opens existing file', () async {
      final fs = ToolTestFilesystemApi()..seedFile('/docs/a.md', 'hello');
      final tool = FsOpenTool();
      await tool.init(
        makeToolContext(
          toolKey: FsOpenTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.activeFiles['/docs/a.md'], 'hello');
    });

    test('fs_open returns error for missing file', () async {
      final fs = ToolTestFilesystemApi();
      final tool = FsOpenTool();
      await tool.init(
        makeToolContext(
          toolKey: FsOpenTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result =
          jsonDecode(await tool.execute({'path': '/docs/missing.md'}))
              as Map<String, dynamic>;
      expect(result['success'], false);
    });

    test('fs_open creates missing file when createIfMissing is true', () async {
      final fs = ToolTestFilesystemApi();
      final tool = FsOpenTool();
      await tool.init(
        makeToolContext(
          toolKey: FsOpenTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(
        await tool.execute({
          'path': '/docs/new.md',
          'createIfMissing': true,
        }),
      ) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.files['/docs/new.md'], '');
      expect(fs.activeFiles['/docs/new.md'], '');
    });

    test('fs_close persists active content and closes file', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/docs/a.md', 'edited');
      final tool = FsCloseTool();
      await tool.init(
        makeToolContext(
          toolKey: FsCloseTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.files['/docs/a.md'], 'edited');
      expect(fs.activeFiles.containsKey('/docs/a.md'), isFalse);
    });

    test('fs_close returns error for unopened file', () async {
      final fs = ToolTestFilesystemApi();
      final tool = FsCloseTool();
      await tool.init(
        makeToolContext(
          toolKey: FsCloseTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], false);
    });

    test('fs_delete deletes path', () async {
      final fs = ToolTestFilesystemApi()..seedFile('/docs/a.md', 'a');
      final tool = FsDeleteTool();
      await tool.init(
        makeToolContext(
          toolKey: FsDeleteTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs/a.md'}))
          as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.files.containsKey('/docs/a.md'), isFalse);
      expect(fs.deletedPaths, ['/docs/a.md']);
    });

    test('fs_move moves path', () async {
      final fs = ToolTestFilesystemApi()..seedFile('/docs/a.md', 'a');
      final tool = FsMoveTool();
      await tool.init(
        makeToolContext(
          toolKey: FsMoveTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({
        'fromPath': '/docs/a.md',
        'toPath': '/docs/b.md',
      })) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(fs.files.containsKey('/docs/a.md'), isFalse);
      expect(fs.files['/docs/b.md'], 'a');
    });

    test('fs_list returns filesystem entries', () async {
      final fs = ToolTestFilesystemApi()
        ..seedFile('/docs/a.md', 'a')
        ..seedFile('/docs/sub/b.md', 'b');
      final tool = FsListTool();
      await tool.init(
        makeToolContext(
          toolKey: FsListTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({'path': '/docs'}))
          as Map<String, dynamic>;
      expect(result['success'], true);
      expect(result['entries'], ['a.md', 'sub/']);
    });

    test('fs_active_files lists active paths sorted', () async {
      final fs = ToolTestFilesystemApi()
        ..seedActiveFile('/b.md', 'b')
        ..seedActiveFile('/a.md', 'a');
      final tool = FsActiveFilesTool();
      await tool.init(
        makeToolContext(
          toolKey: FsActiveFilesTool.toolKeyName,
          filesystemApi: fs,
        ),
      );

      final result = jsonDecode(await tool.execute({})) as Map<String, dynamic>;
      expect(result['success'], true);
      expect(result['count'], 2);
      expect(result['paths'], ['/a.md', '/b.md']);
    });
  });
}
