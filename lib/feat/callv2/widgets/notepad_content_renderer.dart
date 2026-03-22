import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/feat/callv2/widgets/notepad_spreadsheet_content.dart';

class NotepadContentRenderer extends StatelessWidget {
  final String path;
  final String content;
  final bool isEditing;
  final TextEditingController editorController;
  final ValueChanged<String> onContentChanged;

  const NotepadContentRenderer({
    super.key,
    required this.path,
    required this.content,
    required this.isEditing,
    required this.editorController,
    required this.onContentChanged,
  });

  String get _extension {
    return VirtualFile(path: path, content: '').extension.toLowerCase();
  }

  bool get _isSpreadsheet {
    return _extension == '.v2d.csv' ||
        _extension == '.v2d.json' ||
        _extension == '.v2d.jsonl' ||
        _extension == '.csv' ||
        _extension == '.json' ||
        _extension == '.jsonl';
  }

  bool get _isMarkdown {
    return _extension == '.md' || _extension == '.markdown';
  }

  bool get _isHtml {
    return _extension == '.html' || _extension == '.htm';
  }

  @override
  Widget build(BuildContext context) {
    if (_isSpreadsheet) {
      return SpreadsheetContent(
        content: content,
        extension: _extension,
        isEditing: isEditing,
        onContentChanged: onContentChanged,
      );
    }

    if (isEditing) {
      return _buildTextEditor(isMonospace: _isMarkdown || _isHtml);
    }

    if (_isMarkdown) {
      return _buildMarkdownPreview();
    }

    if (_isHtml) {
      return _buildTextPreview(content, monospace: true);
    }

    return _buildTextPreview(content);
  }

  Widget _buildTextEditor({bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: editorController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: onContentChanged,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          height: 1.5,
          fontFamily: isMonospace ? 'monospace' : null,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h4: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h5: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h6: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        code: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: AppTheme.secondaryColor,
          backgroundColor: AppTheme.surfaceColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              width: 4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextPreview(String value, {bool monospace = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        value,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          height: 1.5,
          fontFamily: monospace ? 'monospace' : null,
        ),
      ),
    );
  }
}
