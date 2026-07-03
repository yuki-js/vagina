import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

void main() {
  group('VirtualFilesystemService', () {
    test('normalizes paths before delegating writes to repository', () async {
      final repository = _RecordingVirtualFilesystemRepository();
      final service = VirtualFilesystemService(repository);

      await service.write(
        const VirtualFile(path: '/notes/./draft/../today.md', content: 'hello'),
      );

      expect(repository.writtenFiles.single.path, '/notes/today.md');
      expect(repository.writtenFiles.single.content, 'hello');
    });

    test('does not enforce client-side file-size or quota limits', () async {
      final repository = _RecordingVirtualFilesystemRepository();
      final service = VirtualFilesystemService(repository);
      final oversized =
          'x' * (VirtualFilesystemService.defaultMaxPathLength * 4096);

      await service.write(VirtualFile(path: '/huge.txt', content: oversized));

      expect(repository.writtenFiles.single.content.length, oversized.length);
    });

    test('keeps cheap client-side path validation', () async {
      final repository = _RecordingVirtualFilesystemRepository();
      final service = VirtualFilesystemService(repository);

      expect(
        () => service.write(
          const VirtualFile(path: 'relative.txt', content: 'x'),
        ),
        throwsA(isA<VirtualFilesystemException>()),
      );
      expect(repository.writtenFiles, isEmpty);
    });
  });
}

final class _RecordingVirtualFilesystemRepository
    implements VirtualFilesystemRepository {
  final List<VirtualFile> writtenFiles = <VirtualFile>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async => null;

  @override
  Future<void> write(VirtualFile file) async {
    writtenFiles.add(file);
  }

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> move(String fromPath, String toPath) async {}

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return const <String>[];
  }
}
