import 'package:flutter/material.dart';
import 'package:vagina/models/open_file_tab.dart';
import 'open_files_markdown_content.dart';
import 'open_files_plain_text_content.dart';
import 'open_files_html_content.dart';
import 'open_files_spreadsheet_content.dart';

/// Routes open-file content to the appropriate renderer based on MIME type.
class OpenFilesContentRenderer extends StatelessWidget {
  final OpenFileTab tab;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const OpenFilesContentRenderer({
    super.key,
    required this.tab,
    this.isEditing = false,
    this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (tab.mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        return SpreadsheetContent(
          content: tab.content,
          mimeType: tab.mimeType,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
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
