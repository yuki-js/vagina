import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/chat_message.dart';
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

/// Tool badge widget displayed inline with status indication
class _ToolBadge extends StatelessWidget {
  final ToolCallInfo toolCall;

  const _ToolBadge({required this.toolCall});

  /// Get badge color based on status
  Color _getBadgeColor() {
    switch (toolCall.status) {
      case ToolCallStatus.generating:
      case ToolCallStatus.executing:
        return AppTheme.secondaryColor;
      case ToolCallStatus.completed:
        return AppTheme.secondaryColor;
      case ToolCallStatus.error:
        return Colors.red;
      case ToolCallStatus.cancelled:
        return Colors.grey;
    }
  }

  /// Get icon based on status
  IconData _getIcon() {
    switch (toolCall.status) {
      case ToolCallStatus.generating:
      case ToolCallStatus.executing:
        return Icons.build;
      case ToolCallStatus.completed:
        return Icons.build;
      case ToolCallStatus.error:
        return Icons.error_outline;
      case ToolCallStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  /// Check if spinner should be shown
  bool get _showSpinner =>
      toolCall.status == ToolCallStatus.generating ||
      toolCall.status == ToolCallStatus.executing;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();

    return GestureDetector(
      onTap: () => showToolDetailsSheet(context, toolCall.callId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(), size: 12, color: badgeColor),
            const SizedBox(width: 4),
            Text(
              toolCall.name,
              style: TextStyle(
                fontSize: 11,
                color: badgeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            // Show spinner for generating/executing states
            if (_showSpinner)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: badgeColor,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
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

  /// Build content widgets from content parts in order
  List<Widget> _buildContentWidgets() {
    final widgets = <Widget>[];

    for (int i = 0; i < message.contentParts.length; i++) {
      final part = message.contentParts[i];

      // Add spacing between parts
      if (i > 0) {
        widgets.add(const SizedBox(height: 8));
      }

      if (part is TextPart && part.text.isNotEmpty) {
        widgets.add(
          SelectableText(
            part.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
            ),
          ),
        );
      } else if (part is ToolCallPart) {
        widgets.add(_ToolBadge(toolCall: part.toolCall));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = message.contentParts.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                color: isUser ? AppTheme.primaryColor : AppTheme.surfaceColor,
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
                  // Content parts in order (text and tool calls interleaved)
                  if (hasContent) ..._buildContentWidgets(),
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
