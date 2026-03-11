import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/repositories/json_virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';

void main() {
  group('JsonVirtualFilesystemRepository', () {
    late InMemoryStore store;
    late JsonVirtualFilesystemRepository repository;

    setUp(() async {
      store = InMemoryStore();
      await store.initialize();
      repository = JsonVirtualFilesystemRepository(store);
      await repository.initialize();
    });

    test('initialize creates virtual_fs_root storage shape', () async {
      final root = await store.get('virtual_fs_root') as Map<String, dynamic>;
      expect(root['version'], '1.0');
      expect(root['files'], isA<Map>());
    });

    test('write and read persists file by absolute path', () async {
      const file = VirtualFile(path: '/documents/notes.txt', content: 'hello');
      await repository.write(file);

      final loaded = await repository.read('/documents/notes.txt');
      expect(loaded, isNotNull);
      expect(loaded!.path, '/documents/notes.txt');
      expect(loaded.content, 'hello');
    });

    test('write on existing path overwrites content', () async {
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'before'),
      );
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'after'),
      );

      final loaded = await repository.read('/documents/notes.txt');
      expect(loaded!.content, 'after');
    });

    test('delete removes file if it exists', () async {
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'hello'),
      );

      await repository.delete('/documents/notes.txt');
      final loaded = await repository.read('/documents/notes.txt');
      expect(loaded, isNull);
    });

    test('move renames source path to destination path', () async {
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'hello'),
      );

      await repository.move('/documents/notes.txt', '/documents/archive.txt');

      final oldPath = await repository.read('/documents/notes.txt');
      final newPath = await repository.read('/documents/archive.txt');
      expect(oldPath, isNull);
      expect(newPath, isNotNull);
      expect(newPath!.path, '/documents/archive.txt');
      expect(newPath.content, 'hello');
    });

    test('move throws when source is missing', () async {
      expect(
        () => repository.move('/missing.txt', '/new.txt'),
        throwsA(isA<StateError>()),
      );
    });

    test('move throws when destination already exists', () async {
      await repository.write(
        const VirtualFile(path: '/a.txt', content: 'a'),
      );
      await repository.write(
        const VirtualFile(path: '/b.txt', content: 'b'),
      );

      expect(
        () => repository.move('/a.txt', '/b.txt'),
        throwsA(isA<StateError>()),
      );
    });

    test('list returns immediate children with directory suffix', () async {
      await repository.write(
        const VirtualFile(path: '/README.md', content: '# root'),
      );
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'n'),
      );
      await repository.write(
        const VirtualFile(path: '/documents/projects/plan.md', content: 'p'),
      );

      final rootEntries = await repository.list('/');
      final documentEntries = await repository.list('/documents');

      expect(rootEntries, ['README.md', 'documents/']);
      expect(documentEntries, ['notes.txt', 'projects/']);
    });

    test('list recursive returns descendants relative to requested path',
        () async {
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'n'),
      );
      await repository.write(
        const VirtualFile(path: '/documents/projects/plan.md', content: 'p'),
      );

      final descendants = await repository.list('/documents', recursive: true);
      expect(descendants, ['notes.txt', 'projects/plan.md']);
    });

    test('storage layout is flat map keyed by absolute path', () async {
      await repository.write(
        const VirtualFile(path: '/documents/notes.txt', content: 'hello'),
      );
      await repository.write(
        const VirtualFile(path: '/data/sales.v2d.csv', content: 'a,b\n1,2'),
      );

      final root = await store.get('virtual_fs_root') as Map<String, dynamic>;
      final files = Map<String, dynamic>.from(root['files'] as Map);

      expect(files.keys.toSet(), {
        '/documents/notes.txt',
        '/data/sales.v2d.csv',
      });
      expect(
        (files['/documents/notes.txt'] as Map<String, dynamic>)['content'],
        'hello',
      );
      expect(
        (files['/data/sales.v2d.csv'] as Map<String, dynamic>)['path'],
        '/data/sales.v2d.csv',
      );
    });
  });
}
