import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_message.dart';

/// Shows tool details in a bottom sheet
void showToolDetailsSheet(BuildContext context, ToolCallInfo toolCall) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ToolDetailsSheet(toolCall: toolCall),
  );
}

/// Tool details bottom sheet content
class ToolDetailsSheet extends StatelessWidget {
  final ToolCallInfo toolCall;

  const ToolDetailsSheet({super.key, required this.toolCall});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build, color: AppTheme.secondaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  toolCall.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Arguments section
          const Text(
            '引数:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundStart,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              toolCall.arguments,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Result section
          const Text(
            '結果:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundStart,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              toolCall.result,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
