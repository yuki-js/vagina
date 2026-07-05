import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';

class VirtualFilesystemException implements Exception {
  final String message;

  VirtualFilesystemException(this.message);

  @override
  String toString() => 'VirtualFilesystemException: $message';
}

final class VirtualFilesystemPolicy {
  static const int defaultMaxPathLength = 512;

  final int maxPathLength;
  final Set<String> _reservedPaths = <String>{};

  VirtualFilesystemPolicy({this.maxPathLength = defaultMaxPathLength});

  void reservePath(String path) {
    final normalizedPath = normalizeAndValidatePath(path);
    _reservedPaths.add(normalizedPath);
  }

  void unreservePath(String path) {
    final normalizedPath = normalizeAndValidatePath(path);
    _reservedPaths.remove(normalizedPath);
  }

  void clearReservedPaths() {
    _reservedPaths.clear();
  }

  String validateFilePath(String path) {
    final normalizedPath = validatePath(path);
    if (normalizedPath == '/') {
      throw VirtualFilesystemException('Path must target a file: $path');
    }
    return normalizedPath;
  }

  String validatePath(String path) {
    final normalizedPath = normalizeAndValidatePath(path);
    checkReservedPath(normalizedPath);

    return normalizedPath;
  }

  String normalizeAndValidatePath(String path) {
    if (path.length > maxPathLength) {
      throw VirtualFilesystemException(
        'Path too long (max $maxPathLength chars)',
      );
    }

    if (path.contains('\x00')) {
      throw VirtualFilesystemException('Path contains null byte');
    }

    return normalizePath(path);
  }

  String normalizePath(String path) {
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

  void checkReservedPath(String path) {
    if (_reservedPaths.contains(path) ||
        path == '/system' ||
        path.startsWith('/system/') ||
        path == '/tmp' ||
        path.startsWith('/tmp/')) {
      throw VirtualFilesystemException('Access denied: reserved path');
    }
  }
}

/// Client-side VFS facade.
///
/// Persistent VFS policy is server-authoritative. This service keeps only cheap
/// path normalization checks needed by the in-call UI/tool host before making
/// repository calls; size, quota, and final conflict semantics belong to the API.
class VirtualFilesystemService {
  static const int defaultMaxPathLength =
      VirtualFilesystemPolicy.defaultMaxPathLength;

  final VirtualFilesystemRepository _repository;
  final VirtualFilesystemPolicy _policy;

  VirtualFilesystemService(
    this._repository, {
    int maxPathLength = defaultMaxPathLength,
  }) : _policy = VirtualFilesystemPolicy(maxPathLength: maxPathLength);

  Future<void> initialize() async {
    await _repository.initialize();
  }

  void reservePath(String path) {
    _policy.reservePath(path);
  }

  void unreservePath(String path) {
    _policy.unreservePath(path);
  }

  Future<VirtualFile?> read(String path) async {
    final normalizedPath = _policy.validateFilePath(path);
    return _repository.read(normalizedPath);
  }

  Future<void> write(VirtualFile file) async {
    final normalizedPath = _policy.validateFilePath(file.path);
    await _repository.write(
      VirtualFile(path: normalizedPath, content: file.content),
    );
  }

  Future<void> delete(String path) async {
    final normalizedPath = _policy.validateFilePath(path);
    await _repository.delete(normalizedPath);
  }

  Future<void> move(String fromPath, String toPath) async {
    final normalizedFromPath = _policy.validateFilePath(fromPath);
    final normalizedToPath = _policy.validateFilePath(toPath);

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
    final normalizedPath = _policy.validatePath(path);
    return _repository.list(normalizedPath, recursive: recursive);
  }
}
