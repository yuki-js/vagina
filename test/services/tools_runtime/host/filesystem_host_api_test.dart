import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/repositories/json_virtual_filesystem_repository.dart';
import 'package:vagina/services/tools_runtime/host/filesystem_host_api.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

void main() {
  group('FilesystemHostApi', () {
    late FilesystemHostApi hostApi;

    setUp(() async {
      final store = InMemoryStore();
      await store.initialize();
      final repo = JsonVirtualFilesystemRepository(store);
      final service = VirtualFilesystemService(repo);
      await service.initialize();
      hostApi = FilesystemHostApi(service);
    });

    test('write + read roundtrip', () async {
      await hostApi.handleCall(
        'write',
        {'path': '/docs/a.txt', 'content': 'hello'},
      );

      final read = await hostApi.handleCall('read', {'path': '/docs/a.txt'});
      expect(read, isA<Map>());
      final map = Map<String, dynamic>.from(read as Map);
      expect(map['path'], '/docs/a.txt');
      expect(map['content'], 'hello');
    });

    test('list delegates to filesystem service', () async {
      await hostApi.handleCall(
        'write',
        {'path': '/docs/a.txt', 'content': 'a'},
      );
      await hostApi.handleCall(
        'write',
        {'path': '/docs/sub/b.txt', 'content': 'b'},
      );

      final list = await hostApi.handleCall(
        'list',
        {'path': '/docs', 'recursive': false},
      );

      expect(list, ['a.txt', 'sub/']);
    });

    test('open file runtime state lifecycle', () async {
      await hostApi.handleCall(
        'openFile',
        {'path': '/docs/a.txt', 'content': 'hello'},
      );

      final openFile = await hostApi.handleCall(
        'getActiveFile',
        {'path': '/docs/a.txt'},
      );
      expect((openFile as Map)['content'], 'hello');

      await hostApi.handleCall(
        'updateActiveFile',
        {'path': '/docs/a.txt', 'content': 'updated'},
      );

      final listed = await hostApi.handleCall('listActiveFiles', {});
      expect(listed, hasLength(1));
      expect((listed as List).first['content'], 'updated');

      await hostApi.handleCall('closeFile', {'path': '/docs/a.txt'});
      final closed = await hostApi.handleCall(
        'getActiveFile',
        {'path': '/docs/a.txt'},
      );
      expect(closed, isNull);
    });

    test('emits active file changes callback', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repo = JsonVirtualFilesystemRepository(store);
      final service = VirtualFilesystemService(repo);
      await service.initialize();

      final snapshots = <List<Map<String, String>>>[];
      final notifyingHostApi = FilesystemHostApi(
        service,
        onActiveFilesChanged: (activeFiles) {
          snapshots.add(activeFiles);
        },
      );

      await notifyingHostApi.handleCall(
        'openFile',
        {'path': '/docs/a.txt', 'content': 'hello'},
      );
      await notifyingHostApi.handleCall(
        'updateActiveFile',
        {'path': '/docs/a.txt', 'content': 'updated'},
      );
      await notifyingHostApi.handleCall(
        'closeFile',
        {'path': '/docs/a.txt'},
      );

      expect(snapshots, hasLength(3));
      expect(snapshots[0], [
        {'path': '/docs/a.txt', 'content': 'hello'},
      ]);
      expect(snapshots[1], [
        {'path': '/docs/a.txt', 'content': 'updated'},
      ]);
      expect(snapshots[2], isEmpty);
    });

    test('unknown method throws', () async {
      expect(
        () => hostApi.handleCall('unknown', {}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
