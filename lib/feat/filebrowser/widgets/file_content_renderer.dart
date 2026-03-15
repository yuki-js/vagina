import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/feat/call/widgets/spreadsheet/editable_spreadsheet_table.dart';

/// Light-theme content renderer for file browser.
///
/// Routes file content to the appropriate renderer based on MIME type,
/// using light theme colors suitable for white background.
class FileContentRenderer extends StatelessWidget {
  final String content;
  final String mimeType;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const FileContentRenderer({
    super.key,
    required this.content,
    required this.mimeType,
    this.isEditing = false,
    this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        return _buildSpreadsheet();
      case 'text/markdown':
        return _buildMarkdown();
      case 'text/html':
        return _buildHtml();
      case 'text/plain':
      default:
        return _buildPlainText();
    }
  }

  // ---------------------------------------------------------------------------
  // Spreadsheet
  // ---------------------------------------------------------------------------

  Widget _buildSpreadsheet() {
    TabularData data;
    try {
      data = TabularData.parse(content, mimeType);
    } catch (e) {
      return _buildParseError(e);
    }

    if (data.columns.isEmpty) {
      return const Center(
        child: Text(
          'Empty table',
          style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
        ),
      );
    }

    return EditableSpreadsheetTable(
      data: data,
      mimeType: mimeType,
      readOnly: !isEditing,
      useLightTheme: true,
      shrinkWrap: true,
      onDataChanged: (newData) {
        if (isEditing && onContentChanged != null) {
          try {
            final serialized = newData.serialize(mimeType);
            onContentChanged!(serialized);
          } catch (e) {
            debugPrint('Error serializing data: $e');
          }
        }
      },
    );
  }

  Widget _buildParseError(Object error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.red.withValues(alpha: 0.1),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Parse error: $error',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Markdown
  // ---------------------------------------------------------------------------

  Widget _buildMarkdown() {
    if (isEditing) {
      return _buildMarkdownEditor();
    } else {
      return _buildMarkdownPreview();
    }
  }

  Widget _buildMarkdownEditor() {
    final controller = TextEditingController(text: content);

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        onChanged: onContentChanged,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: AppTheme.lightTextPrimary,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: content.isEmpty ? '_（内容なし）_' : content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppTheme.lightTextPrimary,
          ),
          h1: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
          h2: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
          h3: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
          code: TextStyle(
            backgroundColor: AppTheme.lightTextSecondary.withValues(alpha: 0.1),
            color: AppTheme.primaryColor,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: TextStyle(
            color: AppTheme.lightTextSecondary,
            fontStyle: FontStyle.italic,
          ),
          listBullet: const TextStyle(
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HTML
  // ---------------------------------------------------------------------------

  Widget _buildHtml() {
    if (isEditing) {
      return _buildPlainTextEditor();
    } else {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          content.isEmpty ? '（内容なし）' : content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: AppTheme.lightTextPrimary,
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Plain text
  // ---------------------------------------------------------------------------

  Widget _buildPlainText() {
    if (isEditing) {
      return _buildPlainTextEditor();
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content.isEmpty ? '（内容なし）' : content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppTheme.lightTextPrimary,
          ),
        ),
      );
    }
  }

  Widget _buildPlainTextEditor() {
    final controller = TextEditingController(text: content);

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        onChanged: onContentChanged,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.lightTextPrimary,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
