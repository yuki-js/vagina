import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/state/call_stream_providers.dart';
import 'package:vagina/models/chat_message.dart';

/// Shows tool details in a bottom sheet (reactive version)
void showToolDetailsSheet(BuildContext context, String callId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ToolDetailsSheet(callId: callId),
  );
}

/// Reactive tool details bottom sheet that updates in real-time
class ToolDetailsSheet extends ConsumerWidget {
  final String callId;

  const ToolDetailsSheet({super.key, required this.callId});

  /// Find tool call by callId in the message list
  ToolCallInfo? _findToolCall(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      for (final part in message.contentParts) {
        if (part is ToolCallPart && part.toolCall.callId == callId) {
          return part.toolCall;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch chat stream for reactive updates
    final chatMessagesAsync = ref.watch(chatMessagesProvider);

    return chatMessagesAsync.when(
      data: (messages) {
        final toolCall = _findToolCall(messages);
        
        if (toolCall == null) {
          return _buildErrorState(context, 'Tool call not found');
        }

        return _buildContent(context, toolCall);
      },
      loading: () => _buildLoadingState(context),
      error: (error, stack) => _buildErrorState(context, 'Error: $error'),
    );
  }

  Widget _buildContent(BuildContext context, ToolCallInfo toolCall) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildHeader(toolCall),
          ),
          const SizedBox(height: 16),
          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusSection(toolCall),
                  const SizedBox(height: 12),
                  _buildArgumentsSection(toolCall),
                  const SizedBox(height: 12),
                  if (toolCall.hasResult) ...[
                    _buildResultSection(toolCall),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ToolCallInfo toolCall) {
    final statusColor = _getStatusColor(toolCall);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(toolCall),
            color: statusColor,
            size: 20,
          ),
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
        // Spinner for generating/executing states
        if (_showSpinner(toolCall))
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.secondaryColor,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection(ToolCallInfo toolCall) {
    final statusColor = _getStatusColor(toolCall);

    return Container(
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
            _getStatusIcon(toolCall),
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(toolCall),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArgumentsSection(ToolCallInfo toolCall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: toolCall.arguments != null && toolCall.arguments!.isNotEmpty
              ? SelectableText(
                  toolCall.arguments!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimary,
                  ),
                )
              : Text(
                  toolCall.status == ToolCallStatus.generating
                      ? 'Streaming...'
                      : 'No arguments',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResultSection(ToolCallInfo toolCall) {
    final isError = toolCall.status == ToolCallStatus.error;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isError ? 'エラー:' : '結果:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isError ? Colors.red : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.backgroundStart,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            toolCall.result ?? '',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: isError ? Colors.red : AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Get status color based on tool call status
  Color _getStatusColor(ToolCallInfo toolCall) {
    switch (toolCall.status) {
      case ToolCallStatus.generating:
      case ToolCallStatus.executing:
        return AppTheme.secondaryColor;
      case ToolCallStatus.completed:
        return Colors.green;
      case ToolCallStatus.error:
        return Colors.red;
      case ToolCallStatus.cancelled:
        return Colors.grey;
    }
  }

  /// Get status icon
  IconData _getStatusIcon(ToolCallInfo toolCall) {
    switch (toolCall.status) {
      case ToolCallStatus.generating:
        return Icons.download;
      case ToolCallStatus.executing:
        return Icons.play_arrow;
      case ToolCallStatus.completed:
        return Icons.check_circle;
      case ToolCallStatus.error:
        return Icons.error;
      case ToolCallStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// Get status text
  String _getStatusText(ToolCallInfo toolCall) {
    switch (toolCall.status) {
      case ToolCallStatus.generating:
        return 'Generating arguments...';
      case ToolCallStatus.executing:
        return 'Executing...';
      case ToolCallStatus.completed:
        return 'Completed';
      case ToolCallStatus.error:
        return 'Error';
      case ToolCallStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Check if spinner should be shown
  bool _showSpinner(ToolCallInfo toolCall) =>
      toolCall.status == ToolCallStatus.generating ||
      toolCall.status == ToolCallStatus.executing;
}
