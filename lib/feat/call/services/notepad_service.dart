import 'dart:async';

import 'package:vagina/feat/call/models/active_file.dart';
import 'package:vagina/feat/call/services/virtual_filesystem_service.dart';
import 'package:vagina/feat/call/services/subservice.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/virtual_file.dart';

/// Session-scoped notepad backing service for a single call.
///
/// Owns the full in-call document domain:
/// - Active file registry (in-memory map of path → content)
/// - Stream of active files for external consumers
/// - Write-through persistence to VFS (immediate for tool mutations)
/// - Session export to SessionNotepadTab
final class NotepadService extends SubService {
  final VirtualFilesystemService _vfs;
  final Map<String, String> _activeFiles = <String, String>{};
  final StreamController<List<ActiveFile>> _activeFilesController =
      StreamController<List<ActiveFile>>.broadcast();

  NotepadService(this._vfs);

  /// Stream of active files for UI and orchestrator.
  Stream<List<ActiveFile>> get activeFiles => _activeFilesController.stream;

  /// Validate that a path is valid for filesystem operations.
  ///
  /// Throws [ArgumentError] if the path is:
  /// - Empty string
  /// - Contains null characters
  void _validatePath(String path, String paramName) {
    if (path.isEmpty) {
      logger.warning('Path validation failed: empty path for $paramName');
      throw ArgumentError.value(
        path,
        paramName,
        'Path cannot be empty',
      );
    }

    if (path.contains('\x00')) {
      logger.warning('Path validation failed: null character in $paramName: $path');
      throw ArgumentError.value(
        path,
        paramName,
        'Path cannot contain null characters',
      );
    }
  }

  /// Get current snapshot of active files.
  List<ActiveFile> listActive() {
    return _activeFiles.entries
        .map((entry) => ActiveFile(path: entry.key, content: entry.value))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Open a file and add it to the active set.
  ///
  /// The file is added to the in-memory active set but NOT persisted to VFS.
  /// Call [update] with persist=true to write to VFS.
  Future<void> open(String path, String content) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.info('Opening file: $path (${content.length} chars)');
    _activeFiles[path] = content;
    _emitChanged();
  }

  /// Update active file content.
  ///
  /// [persist] controls whether to write through to VFS immediately.
  /// - true: Tool-driven changes (immediate persistence)
  /// - false: UI-driven changes (defer until explicit save)
  Future<void> update(String path, String content,
      {bool persist = false}) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    if (!_activeFiles.containsKey(path)) {
      logger.warning('Update failed: file not active: $path');
      throw Exception('File is not active: $path');
    }

    logger.info('Updating file: $path (${content.length} chars, persist: $persist)');
    _activeFiles[path] = content;
    _emitChanged();

    if (persist) {
      await _vfs.write(VirtualFile(path: path, content: content));
    }
  }

  /// Close a file and remove it from the active set.
  ///
  /// Does not persist to VFS. Call [update] with persist=true before closing
  /// if you want to save changes.
  Future<void> close(String path) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.info('Closing file: $path');
    _activeFiles.remove(path);
    _emitChanged();
  }

  /// Read a file from VFS.
  ///
  /// This reads from persistent storage, not from the active set.
  /// Use [getActive] to read from the active set.
  Future<String?> read(String path) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.fine('Reading file from VFS: $path');
    final file = await _vfs.read(path);
    if (file != null) {
      logger.fine('File read successfully: $path (${file.content.length} chars)');
    } else {
      logger.fine('File not found: $path');
    }
    return file?.content;
  }

  /// Get active file content by path.
  ///
  /// Returns null if the file is not in the active set.
  String? getActive(String path) {
    return _activeFiles[path];
  }

  /// Write a file to VFS.
  ///
  /// This writes directly to persistent storage.
  /// If the file is active, consider using [update] with persist=true instead.
  Future<void> write(String path, String content) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.info('Writing file to VFS: $path (${content.length} chars)');
    await _vfs.write(VirtualFile(path: path, content: content));
  }

  /// Delete a file from VFS.
  ///
  /// Does not affect the active set. Call [close] separately if needed.
  Future<void> delete(String path) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.info('Deleting file from VFS: $path');
    await _vfs.delete(path);
  }

  /// Move/rename a file in VFS.
  ///
  /// Does not affect the active set. Call [close]/[open] separately if needed.
  Future<void> move(String fromPath, String toPath) async {
    ensureNotDisposed();
    _validatePath(fromPath, 'fromPath');
    _validatePath(toPath, 'toPath');

    logger.info('Moving file in VFS: $fromPath → $toPath');
    await _vfs.move(fromPath, toPath);
  }

  /// List files in VFS.
  Future<List<String>> list(String path, {bool recursive = false}) async {
    ensureNotDisposed();
    _validatePath(path, 'path');

    logger.fine('Listing VFS directory: $path (recursive: $recursive)');
    final files = await _vfs.list(path, recursive: recursive);
    logger.fine('Found ${files.length} files in $path');
    return files;
  }

  /// Export active files as SessionNotepadTabs for session persistence.
  List<SessionNotepadTab> exportSessionTabs() {
    return listActive().map((file) => file.toSessionTab()).toList();
  }

  /// Persist all active files to VFS.
  ///
  /// This is typically called before ending a call to ensure all
  /// active file changes are saved.
  Future<void> persistAll() async {
    ensureNotDisposed();

    logger.info('Persisting all active files (${_activeFiles.length} files)');
    int succeeded = 0;
    int failed = 0;

    for (final entry in _activeFiles.entries) {
      try {
        await _vfs.write(VirtualFile(path: entry.key, content: entry.value));
        succeeded++;
      } catch (e, stackTrace) {
        failed++;
        logger.severe('Failed to persist file: ${entry.key}', e, stackTrace);
        rethrow;
      }
    }

    logger.info('Persist complete: $succeeded succeeded, $failed failed');
  }

  /// Emit active files changed event.
  void _emitChanged() {
    if (!_activeFilesController.isClosed) {
      _activeFilesController.add(listActive());
    }
  }

  @override
  Future<void> start() async {
    await super.start();
    logger.info('Starting NotepadService');
    // Emit initial empty state
    _emitChanged();
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing NotepadService (${_activeFiles.length} active files)');
    await super.dispose();
    await _activeFilesController.close();
    _activeFiles.clear();
    logger.info('NotepadService disposed successfully');
  }
}
