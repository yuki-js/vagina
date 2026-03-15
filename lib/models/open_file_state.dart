class OpenFileState {
  final String path;
  final String content;

  const OpenFileState({
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
    // todo:これいらないよね。拡張子パースでいいじゃん。
    switch (extension) {
      case '.v2d.csv':
        return 'text/csv';
      case '.v2d.json':
        return 'application/vagina-2d+json';
      case '.v2d.jsonl':
        return 'application/vagina-2d+jsonl';
      case '.md':
        return 'text/markdown';
      case '.txt':
        return 'text/plain';
      case '.html':
        return 'text/html';
      default:
        return 'text/plain';
    }
  }
}
