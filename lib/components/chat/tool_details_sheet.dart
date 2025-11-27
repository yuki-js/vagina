import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_message.dart';

/// Modal bottom sheet for displaying tool call details
class ToolDetailsSheet {
  /// Show tool details in a modal bottom sheet
  static void show(BuildContext context, ToolCallInfo toolCall) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ToolDetailsContent(toolCall: toolCall),
    );
  }
}

class _ToolDetailsContent extends StatelessWidget {
  final ToolCallInfo toolCall;

  const _ToolDetailsContent({required this.toolCall});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSection('引数:', toolCall.arguments),
          const SizedBox(height: 12),
          _buildSection('結果:', toolCall.result),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
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
            content,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
