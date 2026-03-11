import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/repositories/json_virtual_filesystem_repository.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

void main() {
  group('VirtualFilesystemService', () {
    late VirtualFilesystemService service;

    setUp(() async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = JsonVirtualFilesystemRepository(store);
      service = VirtualFilesystemService(
        repository,
        maxFileSizeBytes: 10,
        maxTotalSizeBytes: 20,
      );
      await service.initialize();
    });

    test('write/read normalizes path components', () async {
      await service.write(
        const VirtualFile(path: '/documents/../notes.txt', content: 'hello'),
      );

      final file = await service.read('/notes.txt');
      expect(file, isNotNull);
      expect(file!.path, '/notes.txt');
      expect(file.content, 'hello');
    });

    test('write rejects relative path', () async {
      expect(
        () => service.write(
          const VirtualFile(path: 'relative.txt', content: 'hello'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
    });

    test('write rejects path containing null byte', () async {
      expect(
        () => service.write(
          const VirtualFile(path: '/bad\x00name.txt', content: 'hello'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
    });

    test('write rejects path exceeding max length', () async {
      final longPath = '/${'a' * 513}.txt';
      expect(
        () => service.write(
          VirtualFile(path: longPath, content: 'hello'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
    });

    test('normalize keeps paths in root jail', () async {
      await service.write(
        const VirtualFile(path: '/../../../etc/passwd', content: 'data'),
      );

      final file = await service.read('/etc/passwd');
      expect(file, isNotNull);
      expect(file!.path, '/etc/passwd');
    });

    test('write rejects reserved system and tmp paths', () async {
      expect(
        () => service.write(
          const VirtualFile(path: '/system/config.txt', content: 'x'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );

      expect(
        () => service.write(
          const VirtualFile(path: '/tmp/cache.txt', content: 'x'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
    });

    test('reservePath blocks access and unreservePath reopens it', () async {
      service.reservePath('/notes.txt');

      expect(
        () => service.write(
          const VirtualFile(path: '/notes.txt', content: 'hello'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );

      service.unreservePath('/notes.txt');
      await service.write(
        const VirtualFile(path: '/notes.txt', content: 'hello'),
      );

      final file = await service.read('/notes.txt');
      expect(file, isNotNull);
    });

    test('enforces per-file and total quota limits', () async {
      await service.write(
        const VirtualFile(path: '/a.txt', content: '1234567890'),
      );
      await service.write(
        const VirtualFile(path: '/b.txt', content: 'abcdefghij'),
      );

      expect(
        () => service.write(
          const VirtualFile(path: '/c.txt', content: 'z'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );

      expect(
        () => service.write(
          const VirtualFile(path: '/large.txt', content: '01234567890'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
    });

    test('overwrite recalculates total quota using previous file size',
        () async {
      await service.write(
        const VirtualFile(path: '/a.txt', content: '1234567890'),
      );
      await service.write(
        const VirtualFile(path: '/b.txt', content: 'abcdefghij'),
      );

      await service.write(
        const VirtualFile(path: '/a.txt', content: '12345'),
      );
      await service.write(
        const VirtualFile(path: '/c.txt', content: 'zzzzz'),
      );

      final c = await service.read('/c.txt');
      expect(c, isNotNull);
      expect(c!.content, 'zzzzz');
    });

    test('move rejects existing destination and supports no-op same path',
        () async {
      await service.write(
        const VirtualFile(path: '/a.txt', content: 'a'),
      );
      await service.write(
        const VirtualFile(path: '/b.txt', content: 'b'),
      );

      expect(
        () => service.move('/a.txt', '/b.txt'),
        throwsA(isA<VirtualFilesystemException>()),
      );

      await service.move('/a.txt', '/a.txt');
      final a = await service.read('/a.txt');
      expect(a, isNotNull);
    });

    test('list supports normalized directory paths', () async {
      await service.write(
        const VirtualFile(path: '/docs/one.txt', content: '1'),
      );
      await service.write(
        const VirtualFile(path: '/docs/sub/two.txt', content: '2'),
      );

      final entries = await service.list('/docs/./');
      final recursive = await service.list('/docs', recursive: true);

      expect(entries, ['one.txt', 'sub/']);
      expect(recursive, ['one.txt', 'sub/two.txt']);
    });
  });
}
