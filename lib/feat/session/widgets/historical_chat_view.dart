import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/core/widgets/chat_bubble.dart';

/// Read-only chat history viewer for session detail screen
class HistoricalChatView extends StatelessWidget {
  final List<String> chatMessages;

  const HistoricalChatView({
    super.key,
    required this.chatMessages,
  });

  @override
  Widget build(BuildContext context) {
    if (chatMessages.isEmpty) {
      return Container(
        decoration: AppTheme.lightBackgroundGradient,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '会話履歴がありません',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Parse JSON messages
    final messages = chatMessages
        .map((jsonStr) {
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            // Create simple message from stored data
            return ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: json['role'] as String,
              timestamp: DateTime.parse(json['timestamp'] as String),
              isComplete: true,
              contentParts: [
                TextPart(json['content'] as String),
              ],
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<ChatMessage>()
        .toList();

    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return ChatBubble(message: message);
        },
      ),
    );
  }
}
