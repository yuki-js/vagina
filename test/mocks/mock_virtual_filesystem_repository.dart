import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';

class MockVirtualFilesystemRepository implements VirtualFilesystemRepository {
  final Map<String, VirtualFile> files = {};

  @override
  Future<void> initialize() async {
    // No-op for mock
  }

  @override
  Future<VirtualFile?> read(String path) async {
    return files[path];
  }

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
    if (path == '/') {
      return files.keys.toList()..sort();
    }
    
    final prefix = path.endsWith('/') ? path : '$path/';
    return files.keys
        .where((p) => p.startsWith(prefix))
        .map((p) => p.substring(prefix.length))
        .toList()
      ..sort();
  }
}
