import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Renderer for HTML content (read-only preview)
class HtmlRenderer extends StatelessWidget {
  final String content;

  const HtmlRenderer({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    // Simple HTML display as plain text
    // A real implementation would use a webview or HTML parser
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
