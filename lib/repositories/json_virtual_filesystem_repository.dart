import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/log_service.dart';

/// JSON-backed virtual filesystem repository stored under a single key.
class JsonVirtualFilesystemRepository implements VirtualFilesystemRepository {
  static const _tag = 'VirtualFsRepo';
  static const _rootKey = 'virtual_fs_root';
  static const _version = '1.0';

  final KeyValueStore _store;
  final LogService _logService;

  JsonVirtualFilesystemRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> initialize() async {
    final data = await _store.get(_rootKey);
    if (data is Map && data['files'] is Map) {
      return;
    }
    await _saveRoot(_emptyRoot());
  }

  @override
  Future<VirtualFile?> read(String path) async {
    final files = await _loadFiles();
    final raw = files[path];
    if (raw is! Map) return null;
    return VirtualFile.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> write(VirtualFile file) async {
    final root = await _loadRoot();
    final files = _extractFiles(root);
    files[file.path] = file.toJson();
    root['files'] = files;
    await _saveRoot(root);
  }

  @override
  Future<void> delete(String path) async {
    final root = await _loadRoot();
    final files = _extractFiles(root);
    files.remove(path);
    root['files'] = files;
    await _saveRoot(root);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final root = await _loadRoot();
    final files = _extractFiles(root);

    final raw = files[fromPath];
    if (raw == null) {
      throw StateError('Source file not found: $fromPath');
    }
    if (files.containsKey(toPath)) {
      throw StateError('Destination already exists: $toPath');
    }

    final file = VirtualFile.fromJson(Map<String, dynamic>.from(raw)).toJson();
    file['path'] = toPath;
    files.remove(fromPath);
    files[toPath] = file;
    root['files'] = files;
    await _saveRoot(root);
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final normalizedPath = _normalizeListPath(path);
    final keys = (await _loadFiles()).keys.toList()..sort();

    if (recursive) {
      return _listRecursive(keys, normalizedPath);
    }
    return _listImmediate(keys, normalizedPath);
  }

  Map<String, dynamic> _emptyRoot() => {
        'version': _version,
        'files': <String, dynamic>{},
      };

  Future<Map<String, dynamic>> _loadRoot() async {
    final data = await _store.get(_rootKey);
    if (data is! Map) {
      _logService.warn(_tag, 'Missing or invalid root data; reinitializing');
      final root = _emptyRoot();
      await _saveRoot(root);
      return root;
    }

    final root = Map<String, dynamic>.from(data);
    root['version'] = root['version'] ?? _version;
    root['files'] = _extractFiles(root);
    return root;
  }

  Map<String, dynamic> _extractFiles(Map<String, dynamic> root) {
    final raw = root['files'];
    if (raw is! Map) {
      return <String, dynamic>{};
    }
    final files = <String, dynamic>{};
    for (final entry in raw.entries) {
      files[entry.key.toString()] = entry.value;
    }
    return files;
  }

  Future<Map<String, dynamic>> _loadFiles() async {
    final root = await _loadRoot();
    return _extractFiles(root);
  }

  Future<void> _saveRoot(Map<String, dynamic> root) async {
    await _store.set(_rootKey, root);
  }

  String _normalizeListPath(String path) {
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) {
      throw ArgumentError('Path must be absolute: $path');
    }
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  List<String> _listImmediate(List<String> paths, String basePath) {
    final children = <String>{};

    for (final filePath in paths) {
      final relative = _relativePath(basePath, filePath);
      if (relative == null || relative.isEmpty) {
        continue;
      }

      final slashIndex = relative.indexOf('/');
      if (slashIndex == -1) {
        children.add(relative);
      } else {
        children.add('${relative.substring(0, slashIndex)}/');
      }
    }

    final result = children.toList()..sort();
    return result;
  }

  List<String> _listRecursive(List<String> paths, String basePath) {
    final descendants = <String>[];
    for (final filePath in paths) {
      final relative = _relativePath(basePath, filePath);
      if (relative == null || relative.isEmpty) {
        continue;
      }
      descendants.add(relative);
    }
    descendants.sort();
    return descendants;
  }

  String? _relativePath(String basePath, String filePath) {
    if (basePath == '/') {
      if (!filePath.startsWith('/')) return null;
      return filePath.substring(1);
    }

    final prefix = '$basePath/';
    if (!filePath.startsWith(prefix)) {
      return null;
    }
    return filePath.substring(prefix.length);
  }
}
