import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_theme.dart';
import 'notepad_edit_button.dart';

/// Markdown content renderer with edit/preview toggle
class MarkdownContent extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const MarkdownContent({
    super.key,
    required this.content,
    this.onContentChanged,
  });

  @override
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(MarkdownContent oldWidget) {
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
          _buildEditor()
        else
          _buildPreview(),
        Positioned(
          top: 8,
          right: 8,
          child: NotepadEditButton(isEditing: _isEditing, onTap: _toggleEdit),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
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
    );
  }

  Widget _buildPreview() {
    return Markdown(
      data: widget.content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
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
      ),
    );
  }
}
