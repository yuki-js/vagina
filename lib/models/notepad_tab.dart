/// Represents a single notepad tab
class NotepadTab {
  final String id;
  final String title;
  final String content;
  final String mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotepadTab({
    required this.id,
    required this.title,
    required this.content,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  NotepadTab copyWith({
    String? id,
    String? title,
    String? content,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotepadTab(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get metadata as a map (for AI tools)
  Map<String, dynamic> toMetadata() {
    return {
      'id': id,
      'title': title,
      'mimeType': mimeType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'contentLength': content.length,
    };
  }
}
