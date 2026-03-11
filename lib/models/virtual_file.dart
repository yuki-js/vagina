/// A single file node in the virtual filesystem.
///
/// Directories are implicit and derived from file path prefixes.
class VirtualFile {
  final String path;
  final String content;

  const VirtualFile({
    required this.path,
    required this.content,
  });

  /// Derive file extension from path.
  ///
  /// Supports double extensions for tabular files such as `.v2d.csv`.
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

  Map<String, dynamic> toJson() => {
        'path': path,
        'content': content,
      };

  factory VirtualFile.fromJson(Map<String, dynamic> json) {
    return VirtualFile(
      path: json['path'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}
