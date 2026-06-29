import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/realtime/tool_call_resolution.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Read-only renderer for a realtime thread.
///
/// Live chat and historical session detail share this widget so saved sessions
/// are rendered with the same thread terminology and visual treatment as the
/// active call chat pane.
class RealtimeThreadView extends StatelessWidget {
  final List<RealtimeThreadItem> items;
  final ScrollController? scrollController;
  final ValueChanged<RealtimeThreadItem>? onToolTap;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const RealtimeThreadView({
    super.key,
    required this.items,
    this.scrollController,
    this.onToolTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final matchedToolOutputIndices = matchCompletedToolOutputIndices(items);

    return ListView.builder(
      controller: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (!item.isVisible) {
          return const SizedBox.shrink();
        }

        if (item.type == RealtimeThreadItemType.functionCall) {
          return _ToolCallBubble(
            details: _ResolvedToolCallDetails(
              ResolvedRealtimeToolCall.fromThread(
                items,
                index,
                matchedToolOutputIndices,
              ),
            ),
            onTap: onToolTap == null ? null : () => onToolTap!(item),
          );
        }

        if (item.type == RealtimeThreadItemType.functionCallOutput) {
          return const SizedBox.shrink();
        }

        return _RealtimeThreadBubble(item: item);
      },
    );
  }
}

class RealtimeThreadToolDetailsSheet extends StatelessWidget {
  final String itemId;
  final List<RealtimeThreadItem> initialItems;
  final RealtimeService? realtimeService;

  const RealtimeThreadToolDetailsSheet({
    super.key,
    required this.itemId,
    required this.initialItems,
    this.realtimeService,
  });

  @override
  Widget build(BuildContext context) {
    final service = realtimeService;
    if (service == null) {
      return _buildContent(context, initialItems);
    }

    return StreamBuilder<RealtimeThread>(
      stream: service.threadUpdates,
      initialData: service.thread,
      builder: (context, snapshot) {
        final items = snapshot.data?.items ?? initialItems;
        return _buildContent(context, items);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<RealtimeThreadItem> items) {
    final l10n = AppLocalizations.of(context);
    final details = _resolveToolCallDetails(items, itemId);
    if (details == null) {
      return _buildErrorState(context, l10n.callChatToolNotFound);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ToolDetailsHeader(details: details),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToolDetailsStatusSection(details: details),
                  const SizedBox(height: 12),
                  _ToolDetailsSection(
                    title: l10n.callChatToolArgumentsSectionTitle,
                    child: _ToolDetailsCodeBlock(
                      text: details.argumentsDisplayText(l10n),
                      isPlaceholder: details.argumentsPlaceholder,
                    ),
                  ),
                  if (details.hasResult) ...[
                    const SizedBox(height: 12),
                    _ToolDetailsSection(
                      title: details.isError
                          ? l10n.callChatToolErrorSectionTitle
                          : l10n.callChatToolResultSectionTitle,
                      child: _ToolDetailsCodeBlock(
                        text: details.resultDisplayText!,
                        isError: details.isError,
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
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ToolCallBubble extends StatelessWidget {
  final _ResolvedToolCallDetails details;
  final VoidCallback? onTap;

  const _ToolCallBubble({required this.details, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 40),
          _ToolBadge(
            icon: details.badgeIcon,
            label: details.displayTitle(AppLocalizations.of(context)),
            color: details.statusColor,
            active: details.showSpinner,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _RealtimeThreadBubble extends StatelessWidget {
  final RealtimeThreadItem item;

  const _RealtimeThreadBubble({required this.item});

  bool get _isUser => item.role == RealtimeThreadItemRole.user;

  bool get _isIncomplete => item.status != RealtimeThreadItemStatus.completed;

  Color get _bubbleColor =>
      _isUser ? AppTheme.primaryColor : AppTheme.surfaceColor;

  Color get _textColor => _isUser ? Colors.white : AppTheme.textPrimary;

  @override
  Widget build(BuildContext context) {
    final contentWidgets = _buildMessageParts(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
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
                color: _bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(_isUser ? 18 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contentWidgets.isNotEmpty) ...contentWidgets,
                  if (_isIncomplete)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: _TypingIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMessageParts(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final widgets = <Widget>[];

    for (int i = 0; i < item.content.length; i++) {
      final part = item.content[i];
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
      }

      if (part is RealtimeThreadTextPart && part.text.isNotEmpty) {
        widgets.add(
          SelectableText(
            part.text,
            style: TextStyle(color: _textColor, fontSize: 15),
          ),
        );
      } else if (part is RealtimeThreadAudioPart) {
        final displayTxt = (part.transcript?.isNotEmpty ?? false)
            ? part.transcript!
            : '[Audio Input]';
        widgets.add(
          SelectableText(
            displayTxt,
            style: TextStyle(color: _textColor, fontSize: 15),
          ),
        );
      } else if (part is RealtimeThreadImagePart) {
        widgets.add(
          _AttachmentBadge(
            icon: Icons.image_outlined,
            label: part.imageUrl,
            sublabel: l10n.callChatImageDetail(part.detail),
          ),
        );
      }
    }

    return widgets;
  }
}

class _ToolBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  const _ToolBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          if (active)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}

_ResolvedToolCallDetails? _resolveToolCallDetails(
  List<RealtimeThreadItem> items,
  String itemId,
) {
  final resolved = resolveRealtimeToolCall(items, itemId);
  return resolved == null ? null : _ResolvedToolCallDetails(resolved);
}

final class _ResolvedToolCallDetails {
  final ResolvedRealtimeToolCall _resolved;

  const _ResolvedToolCallDetails(this._resolved);

  RealtimeThreadItem get callItem => _resolved.callItem;

  RealtimeToolStage get stage => _resolved.stage;

  String displayTitle(AppLocalizations l10n) =>
      callItem.name ?? l10n.callChatToolFallbackName;

  String? get arguments => _resolved.arguments;

  bool get hasArguments => (arguments ?? '').isNotEmpty;

  String argumentsDisplayText(AppLocalizations l10n) {
    if (hasArguments) {
      return arguments!;
    }
    return switch (stage) {
      RealtimeToolStage.generating => l10n.callChatToolArgumentsStreaming,
      RealtimeToolStage.executing ||
      RealtimeToolStage.completed ||
      RealtimeToolStage.error => l10n.callChatToolArgumentsNone,
      RealtimeToolStage.cancelled => l10n.callChatToolArgumentsCancelled,
    };
  }

  bool get argumentsPlaceholder => !hasArguments;

  String? get result => _resolved.output;

  bool get hasResult => _resolved.hasOutput;

  String? get errorMessage => _resolved.errorMessage;

  String? get resultDisplayText => isError ? (errorMessage ?? result) : result;

  bool get isError => _resolved.isError;

  bool get showSpinner => _resolved.isRunning;

  Color get statusColor {
    return switch (stage) {
      RealtimeToolStage.generating ||
      RealtimeToolStage.executing => AppTheme.secondaryColor,
      RealtimeToolStage.completed => Colors.green,
      RealtimeToolStage.error => Colors.red,
      RealtimeToolStage.cancelled => Colors.grey,
    };
  }

  IconData get statusIcon {
    return switch (stage) {
      RealtimeToolStage.generating => Icons.download,
      RealtimeToolStage.executing => Icons.play_arrow,
      RealtimeToolStage.completed => Icons.check_circle,
      RealtimeToolStage.error => Icons.error,
      RealtimeToolStage.cancelled => Icons.cancel,
    };
  }

  IconData get badgeIcon {
    return switch (stage) {
      RealtimeToolStage.generating ||
      RealtimeToolStage.executing ||
      RealtimeToolStage.completed => Icons.build,
      RealtimeToolStage.error => Icons.error_outline,
      RealtimeToolStage.cancelled => Icons.cancel_outlined,
    };
  }

  String statusText(AppLocalizations l10n) {
    return switch (stage) {
      RealtimeToolStage.generating =>
        l10n.callChatToolStatusGeneratingArguments,
      RealtimeToolStage.executing => l10n.callChatToolStatusExecuting,
      RealtimeToolStage.completed => l10n.callChatToolStatusCompleted,
      RealtimeToolStage.error => l10n.callChatToolStatusError,
      RealtimeToolStage.cancelled => l10n.callChatToolStatusCancelled,
    };
  }
}

class _ToolDetailsHeader extends StatelessWidget {
  final _ResolvedToolCallDetails details;

  const _ToolDetailsHeader({required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = details.statusColor;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(details.statusIcon, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            details.displayTitle(l10n),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (details.showSpinner)
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
}

class _ToolDetailsStatusSection extends StatelessWidget {
  final _ResolvedToolCallDetails details;

  const _ToolDetailsStatusSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = details.statusColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(details.statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details.statusText(l10n),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolDetailsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ToolDetailsSection({required this.title, required this.child});

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
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _ToolDetailsCodeBlock extends StatelessWidget {
  final String text;
  final bool isPlaceholder;
  final bool isError;

  const _ToolDetailsCodeBlock({
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
            : AppTheme.backgroundStart,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          color: isPlaceholder
              ? AppTheme.textSecondary
              : (isError ? Colors.red : AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _AttachmentBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;

  const _AttachmentBadge({
    required this.icon,
    required this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundStart,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if ((sublabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
