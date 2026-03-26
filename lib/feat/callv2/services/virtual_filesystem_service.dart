import 'dart:convert';

import 'package:vagina/feat/callv2/services/subservice.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';

class VirtualFilesystemException implements Exception {
  final String message;

  VirtualFilesystemException(this.message);

  @override
  String toString() => 'VirtualFilesystemException: $message';
}

/// Session-scoped filesystem backing service for a single call.
final class VirtualFilesystemService extends SubService {
  static const int defaultMaxFileSizeBytes = 1024 * 1024; // 1 MB
  static const int defaultMaxTotalSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const int defaultMaxPathLength = 512;

  final VirtualFilesystemRepository _repository;
  final int _maxFileSizeBytes;
  final int _maxTotalSizeBytes;
  final int _maxPathLength;
  final Set<String> _systemPaths = <String>{};

  VirtualFilesystemService(
    this._repository, {
    int maxFileSizeBytes = defaultMaxFileSizeBytes,
    int maxTotalSizeBytes = defaultMaxTotalSizeBytes,
    int maxPathLength = defaultMaxPathLength,
  })  : _maxFileSizeBytes = maxFileSizeBytes,
        _maxTotalSizeBytes = maxTotalSizeBytes,
        _maxPathLength = maxPathLength;

  @override
  Future<void> start() async {
    await super.start();
    logger.info(
        'Starting VirtualFilesystemService (maxFile: ${_maxFileSizeBytes ~/ 1024}KB, maxTotal: ${_maxTotalSizeBytes ~/ 1024 ~/ 1024}MB)');
    await _repository.initialize();
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing VirtualFilesystemService (${_systemPaths.length} reserved paths)');
    await super.dispose();
    _systemPaths.clear();
    logger.info('VirtualFilesystemService disposed successfully');
  }

  void reservePath(String path) {
    _ensureReady();
    final normalizedPath = _normalizeAndValidatePath(path);
    logger.fine('Reserving path: $normalizedPath');
    _systemPaths.add(normalizedPath);
  }

  void unreservePath(String path) {
    _ensureReady();
    final normalizedPath = _normalizeAndValidatePath(path);
    logger.fine('Unreserving path: $normalizedPath');
    _systemPaths.remove(normalizedPath);
  }

  Future<VirtualFile?> read(String path) async {
    _ensureReady();
    final normalizedPath = _validateFilePath(path);
    logger.fine('Reading file: $normalizedPath');
    final file = await _repository.read(normalizedPath);
    if (file != null) {
      logger.fine('File read: $normalizedPath (${file.content.length} chars)');
    } else {
      logger.fine('File not found: $normalizedPath');
    }
    return file;
  }

  Future<void> write(VirtualFile file) async {
    _ensureReady();
    final normalizedPath = _validateFilePath(file.path);
    final contentSize = _byteSize(file.content);

    logger.info('Writing file: $normalizedPath (${contentSize} bytes)');

    if (contentSize > _maxFileSizeBytes) {
      logger.warning(
          'File too large: $normalizedPath ($contentSize > $_maxFileSizeBytes bytes)');
      throw VirtualFilesystemException(
        'File too large (max ${_maxFileSizeBytes} bytes)',
      );
    }

    final current = await _repository.read(normalizedPath);
    final currentSize = current == null ? 0 : _byteSize(current.content);
    final totalSize = await _getTotalSizeBytes();
    final nextTotalSize = totalSize - currentSize + contentSize;

    if (nextTotalSize > _maxTotalSizeBytes) {
      logger.warning(
          'Filesystem quota exceeded: $nextTotalSize > $_maxTotalSizeBytes bytes');
      throw VirtualFilesystemException(
        'Filesystem quota exceeded (max $_maxTotalSizeBytes bytes)',
      );
    }

    await _repository.write(
      VirtualFile(path: normalizedPath, content: file.content),
    );
    logger.fine('File written successfully: $normalizedPath');
  }

  Future<void> delete(String path) async {
    _ensureReady();
    final normalizedPath = _validateFilePath(path);
    logger.info('Deleting file: $normalizedPath');
    await _repository.delete(normalizedPath);
    logger.fine('File deleted successfully: $normalizedPath');
  }

  Future<void> move(String fromPath, String toPath) async {
    _ensureReady();
    final normalizedFromPath = _validateFilePath(fromPath);
    final normalizedToPath = _validateFilePath(toPath);

    logger.info('Moving file: $normalizedFromPath → $normalizedToPath');

    if (normalizedFromPath == normalizedToPath) {
      logger.fine('Source and destination are the same, no-op');
      return;
    }

    final fromFile = await _repository.read(normalizedFromPath);
    if (fromFile == null) {
      logger.warning('Source file not found: $normalizedFromPath');
      throw VirtualFilesystemException(
        'Source file not found: $normalizedFromPath',
      );
    }

    final toFile = await _repository.read(normalizedToPath);
    if (toFile != null) {
      logger.warning('Destination already exists: $normalizedToPath');
      throw VirtualFilesystemException(
        'Destination already exists: $normalizedToPath',
      );
    }

    await _repository.move(normalizedFromPath, normalizedToPath);
    logger.fine('File moved successfully: $normalizedFromPath → $normalizedToPath');
  }

  Future<List<String>> list(String path, {bool recursive = false}) async {
    _ensureReady();
    final normalizedPath = _validatePath(path);
    logger.fine('Listing directory: $normalizedPath (recursive: $recursive)');
    final files = await _repository.list(normalizedPath, recursive: recursive);
    logger.fine('Found ${files.length} files in $normalizedPath');
    return files;
  }

  int _byteSize(String value) => utf8.encode(value).length;

  Future<int> _getTotalSizeBytes() async {
    final relativePaths = await _repository.list('/', recursive: true);
    var total = 0;

    for (final relativePath in relativePaths) {
      final absolutePath = '/$relativePath';
      final file = await _repository.read(absolutePath);
      if (file == null) {
        continue;
      }
      total += _byteSize(file.content);
    }

    return total;
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
      logger.warning('Path too long: ${path.length} > $_maxPathLength chars');
      throw VirtualFilesystemException(
        'Path too long (max $_maxPathLength chars)',
      );
    }

    if (path.contains('\x00')) {
      logger.warning('Path contains null byte: $path');
      throw VirtualFilesystemException('Path contains null byte');
    }

    final normalizedPath = _normalizePath(path);
    return normalizedPath;
  }

  String _normalizePath(String path) {
    if (!path.startsWith('/')) {
      logger.warning('Path must be absolute: $path');
      throw VirtualFilesystemException('Path must be absolute: $path');
    }

    var normalizedInput = path;
    if (normalizedInput != '/' && normalizedInput.endsWith('/')) {
      normalizedInput =
          normalizedInput.substring(0, normalizedInput.length - 1);
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
      logger.warning('Access denied to reserved path: $path');
      throw VirtualFilesystemException('Access denied: reserved path');
    }
  }

  void _ensureReady() {
    ensureNotDisposed();
    if (!isStarted) {
      throw StateError('VirtualFilesystemService has not been started.');
    }
  }
}
