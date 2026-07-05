import 'dart:convert';

import 'package:vagina/feat/call/services/subservice.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/virtual_filesystem_service.dart'
    show VirtualFilesystemException, VirtualFilesystemPolicy;

/// Session-scoped filesystem backing service for a single call.
final class VirtualFilesystemService extends SubService {
  static const int defaultMaxFileSizeBytes = 1024 * 1024; // 1 MB
  static const int defaultMaxTotalSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const int defaultMaxPathLength =
      VirtualFilesystemPolicy.defaultMaxPathLength;

  final VirtualFilesystemRepository _repository;
  final int _maxFileSizeBytes;
  final int _maxTotalSizeBytes;
  final VirtualFilesystemPolicy _policy;

  VirtualFilesystemService(
    this._repository, {
    int maxFileSizeBytes = defaultMaxFileSizeBytes,
    int maxTotalSizeBytes = defaultMaxTotalSizeBytes,
    int maxPathLength = defaultMaxPathLength,
  }) : _maxFileSizeBytes = maxFileSizeBytes,
       _maxTotalSizeBytes = maxTotalSizeBytes,
       _policy = VirtualFilesystemPolicy(maxPathLength: maxPathLength);

  @override
  Future<void> start() async {
    await super.start();
    await _repository.initialize();
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _policy.clearReservedPaths();
  }

  void reservePath(String path) {
    _ensureReady();
    _policy.reservePath(path);
  }

  void unreservePath(String path) {
    _ensureReady();
    _policy.unreservePath(path);
  }

  Future<VirtualFile?> read(String path) async {
    _ensureReady();
    final normalizedPath = _policy.validateFilePath(path);
    return _repository.read(normalizedPath);
  }

  Future<void> write(VirtualFile file) async {
    _ensureReady();
    final normalizedPath = _policy.validateFilePath(file.path);
    final contentSize = _byteSize(file.content);

    if (contentSize > _maxFileSizeBytes) {
      throw VirtualFilesystemException(
        'File too large (max $_maxFileSizeBytes bytes)',
      );
    }

    final current = await _repository.read(normalizedPath);
    final currentSize = current == null ? 0 : _byteSize(current.content);
    final totalSize = await _getTotalSizeBytes();
    final nextTotalSize = totalSize - currentSize + contentSize;

    if (nextTotalSize > _maxTotalSizeBytes) {
      throw VirtualFilesystemException(
        'Filesystem quota exceeded (max $_maxTotalSizeBytes bytes)',
      );
    }

    await _repository.write(
      VirtualFile(path: normalizedPath, content: file.content),
    );
  }

  Future<void> delete(String path) async {
    _ensureReady();
    final normalizedPath = _policy.validateFilePath(path);
    await _repository.delete(normalizedPath);
  }

  Future<void> move(String fromPath, String toPath) async {
    _ensureReady();
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
    _ensureReady();
    final normalizedPath = _policy.validatePath(path);
    return _repository.list(normalizedPath, recursive: recursive);
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

  void _ensureReady() {
    ensureNotDisposed();
    if (!isStarted) {
      throw StateError('VirtualFilesystemService has not been started.');
    }
  }
}
