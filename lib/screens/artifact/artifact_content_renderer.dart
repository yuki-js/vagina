import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/artifact_tab.dart';
import '../../theme/app_theme.dart';

/// Renders artifact content based on MIME type
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
        return _MarkdownContent(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
      case 'text/html':
        return _HtmlContent(content: tab.content);
      case 'text/plain':
      default:
        return _PlainTextContent(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
    }
  }
}

/// Markdown content with edit/preview toggle
class _MarkdownContent extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const _MarkdownContent({
    required this.content,
    this.onContentChanged,
  });

  @override
  State<_MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<_MarkdownContent> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(_MarkdownContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !_isEditing) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing && _controller.text != widget.content) {
      widget.onContentChanged?.call(_controller.text);
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isEditing)
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: AppTheme.textPrimary,
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
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          )
        else
          Markdown(
            data: widget.content,
            selectable: true,
            padding: const EdgeInsets.all(16),
            styleSheet: _buildMarkdownStyleSheet(),
          ),
        
        Positioned(
          top: 8,
          right: 8,
          child: _EditToggleButton(isEditing: _isEditing, onTap: _toggleEdit),
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      h4: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      h5: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      h6: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      p: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      code: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.secondaryColor, backgroundColor: AppTheme.surfaceColor),
      codeblockDecoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8)),
      blockquote: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 4))),
      listBullet: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      tableHead: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      tableBody: const TextStyle(color: AppTheme.textPrimary),
      tableBorder: TableBorder.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
      horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3), width: 1))),
      a: TextStyle(color: AppTheme.primaryColor, decoration: TextDecoration.underline),
      strong: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      em: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
      del: TextStyle(decoration: TextDecoration.lineThrough, color: AppTheme.textSecondary),
      checkbox: TextStyle(color: AppTheme.primaryColor),
    );
  }
}

/// Plain text content with edit/preview toggle
class _PlainTextContent extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const _PlainTextContent({
    required this.content,
    this.onContentChanged,
  });

  @override
  State<_PlainTextContent> createState() => _PlainTextContentState();
}

class _PlainTextContentState extends State<_PlainTextContent> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(_PlainTextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !_isEditing) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing && _controller.text != widget.content) {
      widget.onContentChanged?.call(_controller.text);
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isEditing)
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          )
        else
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.content,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        
        Positioned(
          top: 8,
          right: 8,
          child: _EditToggleButton(isEditing: _isEditing, onTap: _toggleEdit),
        ),
      ],
    );
  }
}

/// HTML content (read-only)
class _HtmlContent extends StatelessWidget {
  final String content;

  const _HtmlContent({required this.content});

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

/// Edit toggle button used across content types
class _EditToggleButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onTap;

  const _EditToggleButton({required this.isEditing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.check : Icons.edit,
              size: 14,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              isEditing ? '完了' : '編集',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
