import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/feat/call/widgets/spreadsheet/editable_spreadsheet_table.dart';

/// Read-only notepad viewer for session detail screen
class HistoricalNotepadView extends StatelessWidget {
  final List<SessionNotepadTab>? notepadTabs;

  const HistoricalNotepadView({
    super.key,
    this.notepadTabs,
  });

  @override
  Widget build(BuildContext context) {
    // Only use structured tabs
    if (notepadTabs != null && notepadTabs!.isNotEmpty) {
      return _buildTabsView(context);
    }

    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_outlined,
              size: 64,
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ノートパッドは空です',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsView(BuildContext context) {
    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notepadTabs!.length,
        itemBuilder: (context, index) {
          final tab = notepadTabs![index];
          return _buildTabCard(context, tab, index + 1);
        },
      ),
    );
  }

  Widget _buildTabCard(
      BuildContext context, SessionNotepadTab tab, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and copy button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$number',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                // MIME type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _getMimeTypeColor(tab.mimeType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getMimeTypeColor(tab.mimeType)
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMimeTypeIcon(tab.mimeType),
                        size: 12,
                        color: _getMimeTypeColor(tab.mimeType),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getMimeTypeLabel(tab.mimeType),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getMimeTypeColor(tab.mimeType),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyTabContent(context, tab),
                  tooltip: 'コピー',
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          // Content
          _buildContent(tab),
        ],
      ),
    );
  }

  Widget _buildContent(SessionNotepadTab tab) {
    // Render based on MIME type
    switch (tab.mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        return _buildSpreadsheetContent(tab);
      case 'text/html':
        return _buildHtmlContent(tab);
      case 'text/markdown':
        return _buildMarkdownContent(tab);
      case 'text/plain':
      default:
        return _buildPlainTextContent(tab);
    }
  }

  Widget _buildSpreadsheetContent(SessionNotepadTab tab) {
    try {
      final data = TabularData.parse(tab.content, tab.mimeType);

      if (data.columns.isEmpty) {
        return _buildEmptyContent();
      }

      return Padding(
        padding: const EdgeInsets.all(20),
        child: EditableSpreadsheetTable(
          data: data,
          mimeType: tab.mimeType,
          readOnly: true,
          useLightTheme: true,
          shrinkWrap: true,
          onDataChanged: (_) {}, // No-op for read-only
        ),
      );
    } catch (e) {
      return _buildParseError(e, tab.content);
    }
  }

  Widget _buildMarkdownContent(SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: tab.content.isEmpty ? '_（内容なし）_' : tab.content,
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

  Widget _buildHtmlContent(SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        tab.content.isEmpty ? '（内容なし）' : tab.content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppTheme.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildPlainTextContent(SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        tab.content.isEmpty ? '（内容なし）' : tab.content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Empty table',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildParseError(Object error, String content) {
    return Padding(
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

  IconData _getMimeTypeIcon(String mimeType) {
    switch (mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        return Icons.table_chart;
      case 'text/markdown':
        return Icons.article;
      case 'text/html':
        return Icons.code;
      case 'text/plain':
      default:
        return Icons.description;
    }
  }

  String _getMimeTypeLabel(String mimeType) {
    switch (mimeType) {
      case 'text/csv':
        return 'CSV表';
      case 'application/vagina-2d+json':
        return 'JSON表';
      case 'application/vagina-2d+jsonl':
        return 'JSONL表';
      case 'text/markdown':
        return 'Markdown';
      case 'text/html':
        return 'HTML';
      case 'text/plain':
      default:
        return 'Plain Text';
    }
  }

  Color _getMimeTypeColor(String mimeType) {
    switch (mimeType) {
      case 'text/csv':
      case 'application/vagina-2d+json':
      case 'application/vagina-2d+jsonl':
        return Colors.green;
      case 'text/markdown':
        return AppTheme.primaryColor;
      case 'text/html':
        return Colors.orange;
      case 'text/plain':
      default:
        return AppTheme.lightTextSecondary;
    }
  }

  void _copyTabContent(BuildContext context, SessionNotepadTab tab) {
    Clipboard.setData(ClipboardData(text: tab.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${tab.title}」の内容をコピーしました'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
