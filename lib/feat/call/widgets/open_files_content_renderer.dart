import 'package:flutter/material.dart';
import 'package:vagina/models/open_file_tab.dart';
import 'package:vagina/models/virtual_file.dart';
import 'open_files_markdown_content.dart';
import 'open_files_plain_text_content.dart';
import 'open_files_html_content.dart';
import 'open_files_spreadsheet_content.dart';

/// Routes open-file content to the appropriate renderer based on file extension.
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
    final extension = VirtualFile(path: tab.title, content: '').extension;

    switch (extension) {
      case '.v2d.csv':
      case '.v2d.json':
      case '.v2d.jsonl':
        return SpreadsheetContent(
          content: tab.content,
          extension: extension,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
      case '.md':
        return MarkdownContent(
          content: tab.content,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
      case '.html':
        return HtmlContent(content: tab.content);
      default:
        return PlainTextContent(
          content: tab.content,
          isEditing: isEditing,
          onContentChanged: onContentChanged,
        );
    }
  }
}
