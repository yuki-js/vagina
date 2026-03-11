import 'dart:convert';

import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

/// Host-side adapter for filesystem API calls from tool sandboxes.
class FilesystemHostApi {
  static const String _tag = 'FilesystemHostApi';

  final VirtualFilesystemService _filesystemService;
  final LogService _logService;

  final Map<String, String> _activeFiles = <String, String>{};

  FilesystemHostApi(
    this._filesystemService, {
    LogService? logService,
  }) : _logService = logService ?? LogService();

  Future<dynamic> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'read':
        return _handleRead(args);
      case 'write':
        return _handleWrite(args);
      case 'delete':
        return _handleDelete(args);
      case 'move':
        return _handleMove(args);
      case 'list':
        return _handleList(args);
      case 'openFile':
        return _handleOpenFile(args);
      case 'getActiveFile':
        return _handleGetActiveFile(args);
      case 'updateActiveFile':
        return _handleUpdateActiveFile(args);
      case 'closeFile':
        return _handleCloseFile(args);
      case 'listActiveFiles':
        return _handleListActiveFiles();
      default:
        _logService.error(_tag, 'Unknown method: $method');
        _logService.error(_tag, 'Request Payload: ${jsonEncode(args)}');
        throw Exception('Unknown method: $method');
    }
  }

  Future<dynamic> _handleRead(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    final file = await _filesystemService.read(path);
    if (file == null) {
      return null;
    }
    return {
      'path': file.path,
      'content': file.content,
    };
  }

  Future<dynamic> _handleWrite(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    final content = _requireString(args, 'content');

    await _filesystemService.write(
      VirtualFile(path: path, content: content),
    );
    return null;
  }

  Future<dynamic> _handleDelete(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    await _filesystemService.delete(path);
    _activeFiles.remove(path);
    return null;
  }

  Future<dynamic> _handleMove(Map<String, dynamic> args) async {
    final fromPath = _requireString(args, 'fromPath');
    final toPath = _requireString(args, 'toPath');

    await _filesystemService.move(fromPath, toPath);
    final activeContent = _activeFiles.remove(fromPath);
    if (activeContent != null) {
      _activeFiles[toPath] = activeContent;
    }
    return null;
  }

  Future<dynamic> _handleList(Map<String, dynamic> args) async {
    final path = (args['path'] as String?) ?? '/';
    final recursive = args['recursive'] as bool? ?? false;
    return _filesystemService.list(path, recursive: recursive);
  }

  Future<dynamic> _handleOpenFile(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    final content = _requireString(args, 'content');
    _activeFiles[path] = content;
    return null;
  }

  Future<dynamic> _handleGetActiveFile(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    final content = _activeFiles[path];
    if (content == null) {
      return null;
    }
    return {
      'path': path,
      'content': content,
    };
  }

  Future<dynamic> _handleUpdateActiveFile(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    final content = _requireString(args, 'content');

    if (!_activeFiles.containsKey(path)) {
      throw Exception('Active file not found: $path');
    }
    _activeFiles[path] = content;
    return null;
  }

  Future<dynamic> _handleCloseFile(Map<String, dynamic> args) async {
    final path = _requireString(args, 'path');
    _activeFiles.remove(path);
    return null;
  }

  Future<dynamic> _handleListActiveFiles() async {
    final entries = _activeFiles.entries
        .map((entry) => {'path': entry.key, 'content': entry.value})
        .toList();
    entries.sort((a, b) {
      final pathA = a['path'] as String;
      final pathB = b['path'] as String;
      return pathA.compareTo(pathB);
    });
    return entries;
  }

  String _requireString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is String) {
      return value;
    }
    throw Exception('Missing required parameter: $key');
  }
}
