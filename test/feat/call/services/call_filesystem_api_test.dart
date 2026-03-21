import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/callv2/services/call_filesystem_api.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';

void main() {
  group('CallFilesystemApi', () {
    late _FakeVirtualFilesystemRepository fakeRepo;
    late VirtualFilesystemService filesystemService;
    late List<List<Map<String, String>>> emittedChanges;
    late CallFilesystemApi api;

    setUp(() {
      fakeRepo = _FakeVirtualFilesystemRepository();
      filesystemService = VirtualFilesystemService(fakeRepo);
      emittedChanges = [];
      api = CallFilesystemApi(
        filesystemService: filesystemService,
        onActiveFilesChanged: (files) => emittedChanges.add(files),
      );
    });

    group('persistence operations', () {
      test('read delegates to VirtualFilesystemService', () async {
        fakeRepo.files['/test.txt'] = VirtualFile(
          path: '/test.txt',
          content: 'hello',
        );

        final result = await api.read('/test.txt');

        expect(result, isNotNull);
        expect(result!['path'], equals('/test.txt'));
        expect(result['content'], equals('hello'));
      });

      test('read returns null when file not found', () async {
        final result = await api.read('/missing.txt');
        expect(result, isNull);
      });

      test('write delegates to VirtualFilesystemService', () async {
        await api.write('/new.txt', 'content');

        final file = fakeRepo.files['/new.txt'];
        expect(file, isNotNull);
        expect(file!.content, equals('content'));
      });

      test('delete removes from VFS and active files', () async {
        fakeRepo.files['/delete.txt'] = VirtualFile(
          path: '/delete.txt',
          content: 'gone',
        );
        await api.openFile('/delete.txt', 'gone');
        emittedChanges.clear();

        await api.delete('/delete.txt');

        expect(fakeRepo.files.containsKey('/delete.txt'), isFalse);
        expect(await api.getActiveFile('/delete.txt'), isNull);
        expect(emittedChanges, hasLength(1));
        expect(emittedChanges.first, isEmpty);
      });

      test('move updates VFS and active files', () async {
        fakeRepo.files['/old.txt'] = VirtualFile(
          path: '/old.txt',
          content: 'data',
        );
        await api.openFile('/old.txt', 'data');
        emittedChanges.clear();

        await api.move('/old.txt', '/new.txt');

        expect(fakeRepo.files.containsKey('/old.txt'), isFalse);
        expect(fakeRepo.files.containsKey('/new.txt'), isTrue);
        expect(await api.getActiveFile('/old.txt'), isNull);
        final newActive = await api.getActiveFile('/new.txt');
        expect(newActive, isNotNull);
        expect(newActive!['content'], equals('data'));
        expect(emittedChanges, hasLength(1));
        expect(emittedChanges.first.first['path'], equals('/new.txt'));
      });

      test('list delegates to VirtualFilesystemService', () async {
        fakeRepo.files['/a.txt'] = VirtualFile(path: '/a.txt', content: '');
        fakeRepo.files['/b.txt'] = VirtualFile(path: '/b.txt', content: '');

        final result = await api.list('/');

        expect(result, containsAll(['a.txt', 'b.txt']));
      });
    });

    group('active file operations', () {
      test('openFile adds to active files and fires callback', () async {
        await api.openFile('/active.txt', 'content');

        expect(emittedChanges, hasLength(1));
        expect(emittedChanges.first, hasLength(1));
        expect(emittedChanges.first.first['path'], equals('/active.txt'));
        expect(emittedChanges.first.first['content'], equals('content'));
      });

      test('getActiveFile returns active file', () async {
        await api.openFile('/test.txt', 'data');

        final result = await api.getActiveFile('/test.txt');

        expect(result, isNotNull);
        expect(result!['path'], equals('/test.txt'));
        expect(result['content'], equals('data'));
      });

      test('getActiveFile returns null for non-active file', () async {
        final result = await api.getActiveFile('/not-active.txt');
        expect(result, isNull);
      });

      test('updateActiveFile updates content and fires callback', () async {
        await api.openFile('/update.txt', 'old');
        emittedChanges.clear();

        await api.updateActiveFile('/update.txt', 'new');

        final result = await api.getActiveFile('/update.txt');
        expect(result!['content'], equals('new'));
        expect(emittedChanges, hasLength(1));
        expect(emittedChanges.first.first['content'], equals('new'));
      });

      test('updateActiveFile throws if file not active', () async {
        expect(
          () => api.updateActiveFile('/not-active.txt', 'data'),
          throwsA(isA<Exception>()),
        );
      });

      test('closeFile removes from active files and fires callback', () async {
        await api.openFile('/close.txt', 'data');
        emittedChanges.clear();

        await api.closeFile('/close.txt');

        expect(await api.getActiveFile('/close.txt'), isNull);
        expect(emittedChanges, hasLength(1));
        expect(emittedChanges.first, isEmpty);
      });

      test('listActiveFiles returns sorted list', () async {
        await api.openFile('/z.txt', 'z');
        await api.openFile('/a.txt', 'a');
        await api.openFile('/m.txt', 'm');

        final result = await api.listActiveFiles();

        expect(result, hasLength(3));
        expect(result[0]['path'], equals('/a.txt'));
        expect(result[1]['path'], equals('/m.txt'));
        expect(result[2]['path'], equals('/z.txt'));
      });
    });

    group('onChange callback', () {
      test('fires with sorted file list', () async {
        await api.openFile('/z.txt', 'z');
        await api.openFile('/a.txt', 'a');

        expect(emittedChanges, hasLength(2));
        final lastChange = emittedChanges.last;
        expect(lastChange[0]['path'], equals('/a.txt'));
        expect(lastChange[1]['path'], equals('/z.txt'));
      });

      test('fires on every active file mutation', () async {
        await api.openFile('/file.txt', 'v1');
        await api.updateActiveFile('/file.txt', 'v2');
        await api.closeFile('/file.txt');

        expect(emittedChanges, hasLength(3));
      });
    });
  });
}

final class _FakeVirtualFilesystemRepository
    implements VirtualFilesystemRepository {
  final Map<String, VirtualFile> files = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async => files[path];

  @override
  Future<void> write(VirtualFile file) async {
    files[file.path] = file;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final file = files.remove(fromPath);
    if (file != null) {
      files[toPath] = VirtualFile(path: toPath, content: file.content);
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return files.keys
        .where((key) => key.startsWith(path))
        .map((key) => key.substring(1))
        .toList();
  }
}
