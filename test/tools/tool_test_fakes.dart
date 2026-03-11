import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';

class ToolTestFilesystemApi implements FilesystemApi {
  final Map<String, String> files = <String, String>{};
  final Map<String, String> activeFiles = <String, String>{};

  final List<String> deletedPaths = <String>[];
  final List<(String fromPath, String toPath)> movedPaths =
      <(String, String)>[];
  final List<(String path, String content)> writes = <(String, String)>[];
  final List<(String path, String content)> activeUpdates =
      <(String, String)>[];

  void seedFile(String path, String content) {
    files[path] = content;
  }

  void seedActiveFile(String path, String content) {
    activeFiles[path] = content;
  }

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final content = files[path];
    if (content == null) {
      return null;
    }
    return {
      'path': path,
      'content': content,
    };
  }

  @override
  Future<void> write(String path, String content) async {
    files[path] = content;
    writes.add((path, content));
  }

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
    files.remove(path);
    activeFiles.remove(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    movedPaths.add((fromPath, toPath));

    final content = files.remove(fromPath);
    if (content != null) {
      files[toPath] = content;
    }

    final activeContent = activeFiles.remove(fromPath);
    if (activeContent != null) {
      activeFiles[toPath] = activeContent;
    }
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final prefix = path == '/' ? '/' : '$path/';
    final result = <String>{};

    for (final filePath in files.keys) {
      if (!filePath.startsWith(prefix)) {
        continue;
      }
      final suffix = filePath.substring(prefix.length);
      if (suffix.isEmpty) {
        continue;
      }

      if (recursive) {
        result.add(suffix);
      } else {
        final slash = suffix.indexOf('/');
        if (slash == -1) {
          result.add(suffix);
        } else {
          result.add('${suffix.substring(0, slash)}/');
        }
      }
    }

    final sorted = result.toList()..sort();
    return sorted;
  }

  @override
  Future<void> openFile(String path, String content) async {
    activeFiles[path] = content;
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final content = activeFiles[path];
    if (content == null) {
      return null;
    }
    return {
      'path': path,
      'content': content,
    };
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    if (!activeFiles.containsKey(path)) {
      throw Exception('Active file not found: $path');
    }
    activeFiles[path] = content;
    activeUpdates.add((path, content));
  }

  @override
  Future<void> closeFile(String path) async {
    activeFiles.remove(path);
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    final entries = activeFiles.entries
        .map((entry) => {'path': entry.key, 'content': entry.value})
        .toList()
      ..sort((a, b) {
        final aPath = a['path'] as String;
        final bPath = b['path'] as String;
        return aPath.compareTo(bPath);
      });
    return entries;
  }
}

class ToolTestCallApi implements CallApi {
  String? lastEndContext;

  @override
  Future<bool> endCall({String? endContext}) async {
    lastEndContext = endContext;
    return true;
  }
}

class ToolTestTextAgentApi implements TextAgentApi {
  @override
  Future<List<Map<String, dynamic>>> listAgents() async => [];

  @override
  Future<String> sendQuery(String agentId, String prompt) async => '';
}

ToolContext makeToolContext({
  required String toolKey,
  required FilesystemApi filesystemApi,
  ToolTestCallApi? callApi,
  TextAgentApi? textAgentApi,
}) {
  return ToolContext(
    toolKey: toolKey,
    filesystemApi: filesystemApi,
    callApi: callApi ?? ToolTestCallApi(),
    textAgentApi: textAgentApi ?? ToolTestTextAgentApi(),
  );
}
