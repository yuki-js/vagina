import 'package:flutter/material.dart';
import '../../models/artifact_tab.dart';
import 'renderers/renderers.dart';

/// Renders artifact content based on MIME type
/// 
/// Delegates rendering to specialized renderers:
/// - [MarkdownRenderer] for text/markdown (GFM compliant)
/// - [PlainTextRenderer] for text/plain
/// - [HtmlRenderer] for text/html
class ArtifactContentRenderer extends StatelessWidget {
  final ArtifactTab tab;
  final void Function(String)? onContentChanged;

  const ArtifactContentRenderer({
    super.key,
    required this.tab,
    this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (tab.mimeType) {
      case 'text/markdown':
        return MarkdownRenderer(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
      case 'text/html':
        return HtmlRenderer(content: tab.content);
      case 'text/plain':
      default:
        return PlainTextRenderer(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
    }
  }
}
