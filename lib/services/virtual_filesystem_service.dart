import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';

class VirtualFilesystemException implements Exception {
  final String message;

  VirtualFilesystemException(this.message);

  @override
  String toString() => 'VirtualFilesystemException: $message';
}

/// Client-side VFS facade.
///
/// Persistent VFS policy is server-authoritative. This service keeps only cheap
/// path normalization checks needed by the in-call UI/tool host before making
/// repository calls; size, quota, and final conflict semantics belong to the API.
class VirtualFilesystemService {
  static const int defaultMaxPathLength = 512;

  final VirtualFilesystemRepository _repository;
  final int _maxPathLength;
  final Set<String> _systemPaths = <String>{};

  VirtualFilesystemService(
    this._repository, {
    int maxPathLength = defaultMaxPathLength,
  }) : _maxPathLength = maxPathLength;

  Future<void> initialize() async {
    await _repository.initialize();
  }

  void reservePath(String path) {
    final normalizedPath = _normalizeAndValidatePath(path);
    _systemPaths.add(normalizedPath);
  }

  void unreservePath(String path) {
    final normalizedPath = _normalizeAndValidatePath(path);
    _systemPaths.remove(normalizedPath);
  }

  Future<VirtualFile?> read(String path) async {
    final normalizedPath = _validateFilePath(path);
    return _repository.read(normalizedPath);
  }

  Future<void> write(VirtualFile file) async {
    final normalizedPath = _validateFilePath(file.path);
    await _repository.write(
      VirtualFile(path: normalizedPath, content: file.content),
    );
  }

  Future<void> delete(String path) async {
    final normalizedPath = _validateFilePath(path);
    await _repository.delete(normalizedPath);
  }

  Future<void> move(String fromPath, String toPath) async {
    final normalizedFromPath = _validateFilePath(fromPath);
    final normalizedToPath = _validateFilePath(toPath);

    if (normalizedFromPath == normalizedToPath) {
      return;
    }

    final fromFile = await _repository.read(normalizedFromPath);
    if (fromFile == null) {
      throw VirtualFilesystemException(
        'Source file not found: $normalizedFromPath',
      );
    }

    final toFile = await _repository.read(normalizedToPath);
    if (toFile != null) {
      throw VirtualFilesystemException(
        'Destination already exists: $normalizedToPath',
      );
    }

    await _repository.move(normalizedFromPath, normalizedToPath);
  }

  Future<List<String>> list(String path, {bool recursive = false}) async {
    final normalizedPath = _validatePath(path);
    return _repository.list(normalizedPath, recursive: recursive);
  }

  String _validateFilePath(String path) {
    final normalizedPath = _validatePath(path);
    if (normalizedPath == '/') {
      throw VirtualFilesystemException('Path must target a file: $path');
    }
    return normalizedPath;
  }

  String _validatePath(String path) {
    final normalizedPath = _normalizeAndValidatePath(path);
    _checkReservedPath(normalizedPath);

    return normalizedPath;
  }

  String _normalizeAndValidatePath(String path) {
    if (path.length > _maxPathLength) {
      throw VirtualFilesystemException(
        'Path too long (max $_maxPathLength chars)',
      );
    }

    if (path.contains('\x00')) {
      throw VirtualFilesystemException('Path contains null byte');
    }

    final normalizedPath = _normalizePath(path);
    return normalizedPath;
  }

  String _normalizePath(String path) {
    if (!path.startsWith('/')) {
      throw VirtualFilesystemException('Path must be absolute: $path');
    }

    var normalizedInput = path;
    if (normalizedInput != '/' && normalizedInput.endsWith('/')) {
      normalizedInput = normalizedInput.substring(
        0,
        normalizedInput.length - 1,
      );
    }

    final parts = normalizedInput
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();

    final normalizedParts = <String>[];
    for (final part in parts) {
      if (part == '..') {
        if (normalizedParts.isNotEmpty) {
          normalizedParts.removeLast();
        }
      } else {
        normalizedParts.add(part);
      }
    }

    if (normalizedParts.isEmpty) {
      return '/';
    }
    return '/${normalizedParts.join('/')}';
  }

  void _checkReservedPath(String path) {
    if (_systemPaths.contains(path) ||
        path == '/system' ||
        path.startsWith('/system/') ||
        path == '/tmp' ||
        path.startsWith('/tmp/')) {
      throw VirtualFilesystemException('Access denied: reserved path');
    }
  }
}
