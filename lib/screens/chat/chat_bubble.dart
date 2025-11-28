import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_message.dart';
import 'tool_details_sheet.dart';

/// Chat bubble widget for displaying messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    
    // Regular message bubble (both user and assistant)
    return _MessageBubble(message: message, isUser: isUser);
  }
}

/// Tool badge widget displayed inline
class _ToolBadge extends StatelessWidget {
  final ToolCallInfo toolCall;

  const _ToolBadge({required this.toolCall});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showToolDetailsSheet(context, toolCall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.secondaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build, size: 12, color: AppTheme.secondaryColor),
            const SizedBox(width: 4),
            Text(
              toolCall.name,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right, 
              size: 12, 
              color: AppTheme.secondaryColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Regular message bubble widget
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;

  const _MessageBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final hasContent = message.content.isNotEmpty;
    final hasToolCalls = message.toolCalls.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser 
                    ? AppTheme.primaryColor 
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tool call badges (displayed first in order)
                  if (hasToolCalls) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.toolCalls.map((toolCall) {
                        return _ToolBadge(toolCall: toolCall);
                      }).toList(),
                    ),
                    if (hasContent) const SizedBox(height: 8),
                  ],
                  // Text content
                  if (hasContent)
                    SelectableText(
                      message.content,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  // Typing indicator for incomplete messages
                  if (!message.isComplete)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: _TypingIndicator(),
                    ),
                ],
              ),
            ),
          ),
          // User avatar removed - position on right side is self-evident
        ],
      ),
    );
  }
}

/// Typing indicator for incomplete messages
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
