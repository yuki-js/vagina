import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/log_service.dart';

/// Chat input area widget
class ChatInput extends ConsumerStatefulWidget {
  final bool isConnected;

  const ChatInput({super.key, required this.isConnected});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  static const _tag = 'ChatInput';
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Add listener for debugging on Windows
    if (Platform.isWindows) {
      _textController.addListener(() {
        logService.debug(_tag, 'Text changed: "${_textController.text}"');
      });
      
      _focusNode.addListener(() {
        logService.debug(_tag, 'Focus changed: ${_focusNode.hasFocus}');
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    final callService = ref.read(callServiceProvider);
    callService.sendTextMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (Platform.isWindows) {
      logService.debug(_tag, 'Key event: ${event.logicalKey}, character: ${event.character}');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget textField = TextField(
      controller: _textController,
      focusNode: _focusNode,
      enabled: widget.isConnected,
      decoration: InputDecoration(
        hintText: widget.isConnected ? 'メッセージを入力...' : '通話中でないと入力できません',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppTheme.backgroundStart,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onSubmitted: (_) => _sendMessage(),
    );
    
    // Wrap with KeyboardListener for debugging on Windows
    if (Platform.isWindows) {
      textField = KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKeyEvent,
        child: textField,
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(child: textField),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: widget.isConnected ? _sendMessage : null,
            backgroundColor: widget.isConnected 
                ? AppTheme.primaryColor 
                : AppTheme.textSecondary,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
