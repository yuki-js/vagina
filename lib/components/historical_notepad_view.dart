import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';

/// Read-only notepad viewer for session detail screen
class HistoricalNotepadView extends StatelessWidget {
  final String? notepadContent;

  const HistoricalNotepadView({
    super.key,
    this.notepadContent,
  });

  @override
  Widget build(BuildContext context) {
    if (notepadContent == null || notepadContent!.isEmpty) {
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

    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: MarkdownBody(
            data: notepadContent!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppTheme.lightTextPrimary,
              ),
              h1: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimary,
              ),
              h2: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimary,
              ),
              h3: const TextStyle(
                fontSize: 20,
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
        ),
      ),
    );
  }
}
