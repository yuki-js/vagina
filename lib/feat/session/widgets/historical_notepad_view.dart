import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/call_session.dart';

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
          Padding(
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
                  backgroundColor:
                      AppTheme.lightTextSecondary.withValues(alpha: 0.1),
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
          ),
        ],
      ),
    );
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
