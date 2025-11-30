import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'notepad_action_bar.dart';

/// HTML content renderer (read-only)
class HtmlContent extends StatelessWidget {
  final String content;

  const HtmlContent({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: NotepadActionBar(
              content: content,
              showEditButton: false,
            ),
          ),
        ),
      ],
    );
  }
}
