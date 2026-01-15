import 'package:flutter/material.dart';
import '../../models/notepad_tab.dart';
import 'notepad_markdown_content.dart';
import 'notepad_plain_text_content.dart';
import 'notepad_html_content.dart';

/// Routes notepad content to the appropriate renderer based on MIME type
class NotepadContentRenderer extends StatelessWidget {
  final NotepadTab tab;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const NotepadContentRenderer({
    super.key,
    required this.tab,
    this.isEditing = false,
    this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (tab.mimeType) {
      case 'text/markdown':
        return MarkdownContent(
          content: tab.content,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
      case 'text/html':
        return HtmlContent(content: tab.content);
      case 'text/plain':
      default:
        return PlainTextContent(
          content: tab.content,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
    }
  }
}
