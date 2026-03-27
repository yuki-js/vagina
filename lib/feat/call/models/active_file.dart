import 'package:vagina/models/call_session.dart';

/// Represents an active file during a call session.
///
/// An active file is a document that has been opened by the agent or user
/// and is being worked on during the current call. The content is kept in
/// memory and may differ from the persisted version in VFS.
class ActiveFile {
  final String path;
  final String content;

  const ActiveFile({
    required this.path,
    required this.content,
  });

  String get title {
    final idx = path.lastIndexOf('/');
    if (idx < 0 || idx == path.length - 1) {
      return path;
    }
    return path.substring(idx + 1);
  }

  String get extension {
    final v2dIndex = path.lastIndexOf('.v2d.');
    if (v2dIndex != -1) {
      return path.substring(v2dIndex);
    }

    final slashIndex = path.lastIndexOf('/');
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex <= slashIndex) {
      return '';
    }
    return path.substring(dotIndex);
  }

  String get mimeType {
    switch (extension) {
      case '.v2d.csv':
      case '.csv':
        return 'text/csv';
      case '.v2d.json':
      case '.json':
        return 'application/json';
      case '.v2d.jsonl':
      case '.jsonl':
        return 'application/jsonl';
      case '.md':
      case '.markdown':
        return 'text/markdown';
      case '.txt':
        return 'text/plain';
      case '.html':
      case '.htm':
        return 'text/html';
      case '.xml':
        return 'application/xml';
      case '.yaml':
      case '.yml':
        return 'application/yaml';
      default:
        return 'text/plain';
    }
  }

  /// Convert to SessionNotepadTab for session export.
  SessionNotepadTab toSessionTab() {
    return SessionNotepadTab(
      title: title,
      content: content,
      mimeType: mimeType,
    );
  }
}
