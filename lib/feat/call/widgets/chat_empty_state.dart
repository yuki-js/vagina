import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

/// Empty state widget for chat when there are no messages
class ChatEmptyState extends StatelessWidget {
  final bool isConnected;

  const ChatEmptyState({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
              isConnected
                  ? '話しかけるか、下のテキストボックスからメッセージを送信してください'
                  : '通話を開始すると、ここに会話が表示されます',
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
