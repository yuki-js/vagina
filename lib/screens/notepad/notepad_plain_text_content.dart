import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Plain text content renderer with edit/preview toggle
class PlainTextContent extends StatefulWidget {
  final String content;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const PlainTextContent({
    super.key,
    required this.content,
    this.isEditing = false,
    this.onContentChanged,
  });

  @override
  State<PlainTextContent> createState() => _PlainTextContentState();
}

class _PlainTextContentState extends State<PlainTextContent> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(PlainTextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !widget.isEditing) {
      _controller.text = widget.content;
    }
    // Notify parent of current content when switching to edit mode
    if (widget.isEditing && !oldWidget.isEditing) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onContentChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      return _buildEditor();
    } else {
      return _buildPreview();
    }
  }

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        onChanged: _onTextChanged,
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
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        widget.content,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
