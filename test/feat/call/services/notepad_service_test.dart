import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/models/active_file.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

import '../../../mocks/mock_virtual_filesystem_repository.dart';

void main() {
  group('NotepadService', () {
    late MockVirtualFilesystemRepository mockRepo;
    late VirtualFilesystemService vfs;
    late NotepadService notepadService;

    setUp(() {
      mockRepo = MockVirtualFilesystemRepository();
      vfs = VirtualFilesystemService(mockRepo);
      notepadService = NotepadService(vfs);
    });

    tearDown(() async {
      await notepadService.dispose();
    });

    test('should start and emit initial empty state', () async {
      final events = <List<ActiveFile>>[];
      notepadService.activeFiles.listen(events.add);

      await notepadService.start();

      await Future.delayed(Duration.zero); // Let stream emit
      expect(events, hasLength(1));
      expect(events[0], isEmpty);
    });

    test('should open file and emit change', () async {
      final events = <List<ActiveFile>>[];
      notepadService.activeFiles.listen(events.add);

      await notepadService.start();
      await notepadService.open('/test.md', 'Hello');

      await Future.delayed(Duration.zero);
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last, hasLength(1));
      expect(events.last[0].path, '/test.md');
      expect(events.last[0].content, 'Hello');
    });

    test('should update active file content without persisting by default',
        () async {
      await notepadService.start();
      await notepadService.open('/test.md', 'Hello');
      await notepadService.update('/test.md', 'Updated');

      expect(notepadService.getActive('/test.md'), 'Updated');
      expect(mockRepo.files['/test.md'], isNull); // Not persisted yet
    });

    test('should update and persist when persist=true', () async {
      await vfs.initialize();
      await notepadService.start();
      await notepadService.open('/test.md', 'Hello');
      await notepadService.update('/test.md', 'Updated', persist: true);

      expect(notepadService.getActive('/test.md'), 'Updated');
      expect(mockRepo.files['/test.md']?.content, 'Updated');
    });

    test('should close file and emit change', () async {
      final events = <List<ActiveFile>>[];
      notepadService.activeFiles.listen(events.add);

      await notepadService.start();
      await notepadService.open('/test.md', 'Hello');
      await notepadService.close('/test.md');

      await Future.delayed(Duration.zero);
      expect(events.last, isEmpty);
      expect(notepadService.getActive('/test.md'), isNull);
    });

    test('should list active files in sorted order', () async {
      await notepadService.start();
      await notepadService.open('/b.txt', 'B');
      await notepadService.open('/a.md', 'A');
      await notepadService.open('/c.csv', 'C');

      final active = notepadService.listActive();
      expect(active, hasLength(3));
      expect(active[0].path, '/a.md');
      expect(active[1].path, '/b.txt');
      expect(active[2].path, '/c.csv');
    });

    test('should read from VFS', () async {
      await vfs.initialize();
      await vfs.write(VirtualFile(path: '/test.md', content: 'Content'));

      final content = await notepadService.read('/test.md');
      expect(content, 'Content');
    });

    test('should export session tabs', () async {
      await notepadService.start();
      await notepadService.open('/doc.md', '# Title');
      await notepadService.open('/data.csv', 'a,b,c');

      final tabs = notepadService.exportSessionTabs();
      expect(tabs, hasLength(2));
      expect(tabs[0].title, 'data.csv');
      expect(tabs[0].content, 'a,b,c');
      expect(tabs[0].mimeType, 'text/csv');
      expect(tabs[1].title, 'doc.md');
      expect(tabs[1].content, '# Title');
      expect(tabs[1].mimeType, 'text/markdown');
    });

    test('should persist all active files', () async {
      await vfs.initialize();
      await notepadService.start();
      await notepadService.open('/a.md', 'Content A');
      await notepadService.open('/b.txt', 'Content B');

      await notepadService.persistAll();

      expect(mockRepo.files['/a.md']?.content, 'Content A');
      expect(mockRepo.files['/b.txt']?.content, 'Content B');
    });

    test('should throw when updating non-active file', () async {
      await notepadService.start();

      expect(
        () => notepadService.update('/nonexistent.md', 'content'),
        throwsException,
      );
    });

    test('should throw when disposed', () async {
      await notepadService.start();
      await notepadService.dispose();

      expect(() => notepadService.open('/test.md', 'content'), throwsStateError);
    });
  });
}
