import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';

class ChatPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const ChatPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
        ),
        const Expanded(
          child: _ChatEmptyState(),
        ),
        _ChatInputShell(controller: _textController),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const _ChatHeader({
    required this.onBackPressed,
    required this.hideBackButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!hideBackButton)
            const SizedBox(width: 80),
          Expanded(
            child: Center(
              child: Text(
                'チャット',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          if (!hideBackButton)
            GestureDetector(
              onTap: onBackPressed,
              child: Row(
                children: [
                  Text(
                    '通話画面',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'まだ会話がありません',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ここに会話履歴が表示されます',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputShell extends StatelessWidget {
  final TextEditingController controller;

  const _ChatInputShell({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: false,
              decoration: InputDecoration(
                hintText: '通話中でないと入力できません',
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
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: null,
            icon: const Icon(
              Icons.send,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
