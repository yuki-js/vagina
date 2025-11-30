import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'notepad_action_bar.dart';

/// Plain text content renderer with edit/preview toggle
class PlainTextContent extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const PlainTextContent({
    super.key,
    required this.content,
    this.onContentChanged,
  });

  @override
  State<PlainTextContent> createState() => _PlainTextContentState();
}

class _PlainTextContentState extends State<PlainTextContent> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(PlainTextContent oldWidget) {
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
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: NotepadActionBar(
              content: _isEditing ? _controller.text : widget.content,
              isEditing: _isEditing,
              onEditToggle: _toggleEdit,
            ),
          ),
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
