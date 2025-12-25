import '../../utils/platform_compat.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/log_service.dart';

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
  static const _tag = 'PlainTextContent';
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final FocusNode? _keyboardListenerFocusNode = PlatformCompat.isWindows ? FocusNode() : null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    
    // Add listener for debugging on Windows
    if (PlatformCompat.isWindows) {
      _controller.addListener(() {
        logService.debug(_tag, 'Text changed: length=${_controller.text.length}');
      });
      
      _focusNode.addListener(() {
        logService.debug(_tag, 'Focus changed: ${_focusNode.hasFocus}');
      });
    }
  }

  @override
  void didUpdateWidget(PlainTextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !widget.isEditing) {
      _controller.text = widget.content;
    }
    // Sync controller text when entering edit mode
    if (widget.isEditing && !oldWidget.isEditing) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _keyboardListenerFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onContentChanged?.call(value);
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (PlatformCompat.isWindows) {
      logService.debug(_tag, 'Key event: ${event.logicalKey}, character: ${event.character}');
    }
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
    Widget textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
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
    );
    
    // Wrap with KeyboardListener for debugging on Windows
    if (PlatformCompat.isWindows && _keyboardListenerFocusNode != null) {
      textField = KeyboardListener(
        focusNode: _keyboardListenerFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: textField,
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: textField,
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
