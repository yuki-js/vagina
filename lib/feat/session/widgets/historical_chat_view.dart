import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

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
        color: AppTheme.lightBackgroundStart,
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
            return {
              'role': json['role'] as String,
              'content': json['content'] as String? ?? '',
              'timestamp': DateTime.parse(json['timestamp'] as String),
              'toolCalls': json['toolCalls'] as List<dynamic>?,
            };
          } catch (e) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return Container(
      color: AppTheme.lightBackgroundStart,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final role = message['role'] as String;
          final content = message['content'] as String;
          final timestamp = message['timestamp'] as DateTime;
          final toolCalls = message['toolCalls'] as List<dynamic>?;
          final isUser = role == 'user';

          // Tool call item - display as badge only
          if (toolCalls != null && toolCalls.isNotEmpty) {
            return _ToolCallItem(
              toolCalls: toolCalls
                  .map((tc) => tc as Map<String, dynamic>)
                  .toList(),
              timestamp: timestamp,
            );
          }

          // Regular message item
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar only for AI
                if (!isUser) ...[
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(
                      Icons.smart_toy,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Chat bubble
                Flexible(
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppTheme.primaryColor
                              : AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                        ),
                        child: SelectableText(
                          content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: isUser
                                ? Colors.white
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      // Timestamp below bubble
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                        child: Text(
                          DateFormat('HH:mm:ss').format(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.lightTextSecondary
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Widget for displaying tool call badges
class _ToolCallItem extends StatelessWidget {
  final List<Map<String, dynamic>> toolCalls;
  final DateTime timestamp;

  const _ToolCallItem({
    required this.toolCalls,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar space (aligned with assistant messages)
          const SizedBox(width: 40), // 16 (radius) * 2 + 8 (spacing)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tool badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: toolCalls.map((toolCall) {
                    return _ToolBadge(
                      name: toolCall['name'] as String? ?? 'unknown',
                      status: toolCall['status'] as String? ?? 'completed',
                      onTap: () => _showToolDetails(context, toolCall),
                    );
                  }).toList(),
                ),
                // Timestamp below badges
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(
                    DateFormat('HH:mm:ss').format(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.lightTextSecondary
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showToolDetails(BuildContext context, Map<String, dynamic> toolCall) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.lightSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ToolDetailsSheet(toolCall: toolCall),
    );
  }
}

/// Tool badge widget matching CallV2 design
class _ToolBadge extends StatelessWidget {
  final String name;
  final String status;
  final VoidCallback onTap;

  const _ToolBadge({
    required this.name,
    required this.status,
    required this.onTap,
  });

  Color get _statusColor {
    return switch (status) {
      'executing' || 'generating' => AppTheme.secondaryColor,
      'completed' => Colors.green,
      'error' => Colors.red,
      'cancelled' => Colors.grey,
      _ => Colors.green,
    };
  }

  IconData get _icon {
    return switch (status) {
      'error' => Icons.error_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.build,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: _statusColor),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 12,
              color: _statusColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tool details bottom sheet
class _ToolDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> toolCall;

  const _ToolDetailsSheet({required this.toolCall});

  @override
  Widget build(BuildContext context) {
    final name = toolCall['name'] as String? ?? 'unknown';
    final status = toolCall['status'] as String? ?? 'completed';
    final arguments = toolCall['arguments'] as String?;
    final result = toolCall['result'] as String?;
    final errorMessage = toolCall['errorMessage'] as String?;
    final isError = status == 'error';

    final statusColor = switch (status) {
      'executing' || 'generating' => AppTheme.secondaryColor,
      'completed' => Colors.green,
      'error' => Colors.red,
      'cancelled' => Colors.grey,
      _ => Colors.green,
    };

    final statusIcon = switch (status) {
      'generating' => Icons.download,
      'executing' => Icons.play_arrow,
      'completed' => Icons.check_circle,
      'error' => Icons.error,
      'cancelled' => Icons.cancel,
      _ => Icons.check_circle,
    };

    final statusText = switch (status) {
      'generating' => 'Generating arguments...',
      'executing' => 'Executing...',
      'completed' => 'Completed',
      'error' => 'Error',
      'cancelled' => 'Cancelled',
      _ => 'Completed',
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          statusIcon,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Arguments section
                  _DetailSection(
                    title: '引数',
                    child: _CodeBlock(
                      text: arguments?.isNotEmpty ?? false
                          ? arguments!
                          : 'No arguments',
                      isPlaceholder: arguments?.isEmpty ?? true,
                    ),
                  ),
                  // Result section
                  if (result != null || errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: isError ? 'エラー' : '結果',
                      child: _CodeBlock(
                        text: errorMessage ?? result ?? '',
                        isError: isError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  final bool isPlaceholder;
  final bool isError;

  const _CodeBlock({
    required this.text,
    this.isPlaceholder = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.1)
            : AppTheme.lightBackgroundStart,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          color: isPlaceholder
              ? AppTheme.lightTextSecondary
              : (isError ? Colors.red : AppTheme.lightTextPrimary),
        ),
      ),
    );
  }
}
