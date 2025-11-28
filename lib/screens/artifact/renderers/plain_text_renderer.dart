import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Renderer for plain text content (editable)
class PlainTextRenderer extends StatefulWidget {
  final String content;
  final void Function(String)? onContentChanged;

  const PlainTextRenderer({
    super.key,
    required this.content,
    this.onContentChanged,
  });

  @override
  State<PlainTextRenderer> createState() => _PlainTextRendererState();
}

class _PlainTextRendererState extends State<PlainTextRenderer> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(PlainTextRenderer oldWidget) {
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
          _PlainTextEditor(controller: _controller)
        else
          _PlainTextPreview(content: widget.content),
        
        // Edit/Done button
        Positioned(
          top: 8,
          right: 8,
          child: _EditToggleButton(
            isEditing: _isEditing,
            onTap: _toggleEdit,
          ),
        ),
      ],
    );
  }
}

/// Button to toggle between edit and preview mode
class _EditToggleButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onTap;

  const _EditToggleButton({
    required this.isEditing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              isEditing ? Icons.check : Icons.edit,
              size: 14,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              isEditing ? '完了' : '編集',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain text editor
class _PlainTextEditor extends StatelessWidget {
  final TextEditingController controller;

  const _PlainTextEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        style: const TextStyle(
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

/// Plain text preview
class _PlainTextPreview extends StatelessWidget {
  final String content;

  const _PlainTextPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
