import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// HTML content renderer (read-only)
class HtmlContent extends StatelessWidget {
  final String content;

  const HtmlContent({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
