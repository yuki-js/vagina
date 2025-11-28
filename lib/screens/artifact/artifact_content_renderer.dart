import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/artifact_tab.dart';

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
        return _MarkdownRenderer(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
      case 'text/html':
        return _HtmlRenderer(content: tab.content);
      case 'text/plain':
      default:
        return _PlainTextRenderer(
          content: tab.content,
          onContentChanged: onContentChanged,
        );
    }
  }
}

/// Renderer for markdown content (editable)
class _MarkdownRenderer extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const _MarkdownRenderer({
    required this.content,
    this.onContentChanged,
  });

  @override
  State<_MarkdownRenderer> createState() => _MarkdownRendererState();
}

class _MarkdownRendererState extends State<_MarkdownRenderer> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(_MarkdownRenderer oldWidget) {
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
          _EditableContent(
            controller: _controller,
            onDone: _toggleEdit,
          )
        else
          _MarkdownPreview(content: widget.content),
        
        // Edit/Done button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isEditing ? Icons.check : Icons.edit,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isEditing ? '完了' : '編集',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Editable text content
class _EditableContent extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDone;

  const _EditableContent({
    required this.controller,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
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
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
            ),
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

/// Simple markdown preview (renders markdown-like formatting)
class _MarkdownPreview extends StatelessWidget {
  final String content;

  const _MarkdownPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        _parseMarkdown(content),
      ),
    );
  }

  TextSpan _parseMarkdown(String text) {
    final List<InlineSpan> spans = [];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      
      // Headers
      if (line.startsWith('### ')) {
        spans.add(TextSpan(
          text: line.substring(4),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ));
      } else if (line.startsWith('## ')) {
        spans.add(TextSpan(
          text: line.substring(3),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ));
      } else if (line.startsWith('# ')) {
        spans.add(TextSpan(
          text: line.substring(2),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        // Bullet points
        spans.add(TextSpan(
          text: '• ${line.substring(2)}',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ));
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        // Numbered lists
        spans.add(TextSpan(
          text: line,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ));
      } else if (line.startsWith('> ')) {
        // Blockquotes
        spans.add(TextSpan(
          text: line.substring(2),
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (line.startsWith('```')) {
        // Code blocks (simple handling)
        spans.add(TextSpan(
          text: line,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: AppTheme.secondaryColor,
          ),
        ));
      } else {
        // Regular text - handle inline formatting
        spans.add(_parseInlineMarkdown(line));
      }
    }
    
    return TextSpan(children: spans);
  }

  TextSpan _parseInlineMarkdown(String text) {
    // Simple inline parsing for bold and italic
    // This is a simplified version - a full markdown parser would be more complex
    
    final List<InlineSpan> spans = [];
    var currentText = text;
    
    // Handle **bold**
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    final italicRegex = RegExp(r'\*(.+?)\*');
    final codeRegex = RegExp(r'`(.+?)`');
    
    while (currentText.isNotEmpty) {
      final boldMatch = boldRegex.firstMatch(currentText);
      final italicMatch = italicRegex.firstMatch(currentText);
      final codeMatch = codeRegex.firstMatch(currentText);
      
      // Find the earliest match
      Match? earliest;
      String type = '';
      
      // Check bold first
      if (boldMatch != null) {
        earliest = boldMatch;
        type = 'bold';
      }
      // Check if italic is earlier
      if (italicMatch != null && (earliest == null || italicMatch.start < earliest.start)) {
        earliest = italicMatch;
        type = 'italic';
      }
      // Check if code is earlier
      if (codeMatch != null && (earliest == null || codeMatch.start < earliest.start)) {
        earliest = codeMatch;
        type = 'code';
      }
      
      if (earliest == null) {
        // No more formatting, add remaining text
        spans.add(TextSpan(
          text: currentText,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ));
        break;
      }
      
      // Add text before the match
      if (earliest.start > 0) {
        spans.add(TextSpan(
          text: currentText.substring(0, earliest.start),
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ));
      }
      
      // Add the formatted text
      final content = earliest.group(1) ?? '';
      switch (type) {
        case 'bold':
          spans.add(TextSpan(
            text: content,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ));
          break;
        case 'italic':
          spans.add(TextSpan(
            text: content,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppTheme.textPrimary,
            ),
          ));
          break;
        case 'code':
          spans.add(TextSpan(
            text: content,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppTheme.secondaryColor,
              backgroundColor: AppTheme.surfaceColor,
            ),
          ));
          break;
      }
      
      currentText = currentText.substring(earliest.end);
    }
    
    return TextSpan(children: spans);
  }
}

/// Renderer for HTML content (read-only preview)
class _HtmlRenderer extends StatelessWidget {
  final String content;

  const _HtmlRenderer({required this.content});

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

/// Renderer for plain text content (editable)
class _PlainTextRenderer extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const _PlainTextRenderer({
    required this.content,
    this.onContentChanged,
  });

  @override
  State<_PlainTextRenderer> createState() => _PlainTextRendererState();
}

class _PlainTextRendererState extends State<_PlainTextRenderer> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(_PlainTextRenderer oldWidget) {
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
          _EditableContent(
            controller: _controller,
            onDone: _toggleEdit,
          )
        else
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        
        // Edit/Done button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isEditing ? Icons.check : Icons.edit,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isEditing ? '完了' : '編集',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
