import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/feat/call/widgets/spreadsheet/editable_spreadsheet_table.dart';
import 'package:vagina/utils/file_icon_utils.dart';

/// Read-only notepad viewer for session detail screen
class HistoricalNotepadView extends StatelessWidget {
  final List<SessionNotepadTab>? notepadTabs;

  const HistoricalNotepadView({
    super.key,
    this.notepadTabs,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Only use structured tabs
    if (notepadTabs != null && notepadTabs!.isNotEmpty) {
      return _buildTabsView(context);
    }

    return Container(
      color: AppTheme.lightBackgroundStart,
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
              l10n.sessionDetailHistoricalNotepadEmpty,
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
      color: AppTheme.lightBackgroundStart,
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
                // File type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorForPath(tab.title).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: colorForPath(tab.title).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconForPath(tab.title),
                        size: 12,
                        color: colorForPath(tab.title),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getFileTypeLabel(context, tab.title),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorForPath(tab.title),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyTabContent(context, tab),
                  tooltip: AppLocalizations.of(context)
                      .sessionDetailHistoricalNotepadCopyTooltip,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          // Content
          _buildContent(context, tab),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SessionNotepadTab tab) {
    final lowerTitle = tab.title.toLowerCase();

    if (lowerTitle.endsWith('.v2d.csv') ||
        lowerTitle.endsWith('.v2d.json') ||
        lowerTitle.endsWith('.v2d.jsonl')) {
      return _buildSpreadsheetContent(context, tab);
    }

    if (lowerTitle.endsWith('.html') || lowerTitle.endsWith('.htm')) {
      return _buildHtmlContent(context, tab);
    }

    if (lowerTitle.endsWith('.md') || lowerTitle.endsWith('.markdown')) {
      return _buildMarkdownContent(context, tab);
    }

    return _buildPlainTextContent(context, tab);
  }

  Widget _buildSpreadsheetContent(BuildContext context, SessionNotepadTab tab) {
    try {
      final lowerTitle = tab.title.toLowerCase();
      final extension = lowerTitle.contains('.v2d.')
          ? lowerTitle.substring(lowerTitle.lastIndexOf('.v2d.'))
          : '';

      final data = TabularData.parse(tab.content, extension);

      if (data.columns.isEmpty) {
        return _buildEmptyContent(context);
      }

      return Padding(
        padding: const EdgeInsets.all(20),
        child: EditableSpreadsheetTable(
          data: data,
          extension: extension,
          readOnly: true,
          useLightTheme: true,
          onDataChanged: (_) {}, // No-op for read-only
        ),
      );
    } catch (e) {
      return _buildParseError(context, e, tab.content);
    }
  }

  Widget _buildMarkdownContent(BuildContext context, SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: tab.content.isEmpty
            ? '_${AppLocalizations.of(context).sessionDetailNoContent}_'
            : tab.content,
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

  Widget _buildHtmlContent(BuildContext context, SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        tab.content.isEmpty
            ? AppLocalizations.of(context).sessionDetailNoContent
            : tab.content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppTheme.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildPlainTextContent(BuildContext context, SessionNotepadTab tab) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        tab.content.isEmpty
            ? AppLocalizations.of(context).sessionDetailNoContent
            : tab.content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          AppLocalizations.of(context).callNotepadSpreadsheetEmptyTable,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildParseError(BuildContext context, Object error, String content) {
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
              AppLocalizations.of(context)
                  .callNotepadSpreadsheetParseError(error.toString()),
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

  String _getFileTypeLabel(BuildContext context, String filename) {
    final l10n = AppLocalizations.of(context);
    final lower = filename.toLowerCase();

    if (lower.endsWith('.v2d.csv')) return l10n.sessionDetailFileTypeCsvTable;
    if (lower.endsWith('.v2d.json')) return l10n.sessionDetailFileTypeJsonTable;
    if (lower.endsWith('.v2d.jsonl')) return l10n.sessionDetailFileTypeJsonlTable;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return l10n.sessionDetailFileTypeMarkdown;
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return l10n.sessionDetailFileTypeHtml;
    }
    if (lower.endsWith('.txt') || lower.endsWith('.text')) {
      return l10n.sessionDetailFileTypeText;
    }
    if (lower.endsWith('.csv')) return l10n.sessionDetailFileTypeCsv;
    if (lower.endsWith('.json')) return l10n.sessionDetailFileTypeJson;
    if (lower.endsWith('.jsonl')) return l10n.sessionDetailFileTypeJsonl;

    return l10n.sessionDetailFileTypeFile;
  }

  void _copyTabContent(BuildContext context, SessionNotepadTab tab) {
    Clipboard.setData(ClipboardData(text: tab.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)
            .sessionDetailHistoricalNotepadCopied(tab.title)),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
