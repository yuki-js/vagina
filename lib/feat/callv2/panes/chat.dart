import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/callv2/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/callv2/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/realtime_service.dart';

class ChatPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;
  final CallService callService;

  const ChatPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
    required this.callService,
  });

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<RealtimeThread>? _threadSubscription;
  StreamSubscription<RealtimeAdapterConnectionState>?
      _connectionStateSubscription;
  List<RealtimeThreadItem> _items = const <RealtimeThreadItem>[];
  bool _isConnected = false;
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;
  RealtimeService? _boundRealtimeService;

  RealtimeService? get _realtimeService => widget.callService.realtimeService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    _bindRealtimeService(_realtimeService);
  }

  @override
  void didUpdateWidget(covariant ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    final realtimeService = _realtimeService;
    if (identical(_boundRealtimeService, realtimeService)) {
      return;
    }

    _bindRealtimeService(realtimeService);
    setState(() {});
  }

  void _bindRealtimeService(RealtimeService? service) {
    _threadSubscription?.cancel();
    _threadSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _boundRealtimeService = service;

    _items = service?.thread.items ?? const <RealtimeThreadItem>[];
    _isConnected = service?.isConnected ?? false;

    if (service == null) {
      return;
    }

    _threadSubscription = service.threadUpdates.listen((thread) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = thread.items;
      });
    });

    _connectionStateSubscription = service.connectionStates.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = state.isConnected;
      });
    });
  }

  @override
  void dispose() {
    _threadSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isAtBottom = currentScroll >= maxScroll - 50;
    final shouldShowScrollButton = !isAtBottom;

    if (isAtBottom != _isAtBottom ||
        shouldShowScrollButton != _showScrollToBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
        _showScrollToBottom = shouldShowScrollButton;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showToolDetailsSheet(RealtimeThreadItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ToolDetailsSheet(
        itemId: item.id,
        initialItems: _items,
        realtimeService: _realtimeService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
        ),
        Expanded(
          child: _items.isEmpty
              ? const _ChatEmptyState()
              : Builder(
                  builder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_isAtBottom && _scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return Stack(
                      children: [
                        _ChatMessageList(
                          items: _items,
                          scrollController: _scrollController,
                          onToolTap: _showToolDetailsSheet,
                        ),
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _ScrollToBottomButton(
                                onPressed: _scrollToBottom,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        _ChatInputShell(
          controller: _textController,
          enabled: _isConnected,
          onSend: _handleSendMessage,
        ),
      ],
    );
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final callService = widget.callService;
    if (callService.state != CallState.active) {
      return;
    }

    // Send text through CallService to ensure interrupt logic is executed
    callService.sendTextMessage(text);
    _textController.clear();
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
          if (!hideBackButton) const SizedBox(width: 80),
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

class _ChatMessageList extends StatelessWidget {
  final List<RealtimeThreadItem> items;
  final ScrollController scrollController;
  final ValueChanged<RealtimeThreadItem> onToolTap;

  const _ChatMessageList({
    required this.items,
    required this.scrollController,
    required this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    final matchedToolOutputIndices = _matchCompletedToolOutputIndices(items);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // ツール呼び出しはバッジで表示
        if (item.type == RealtimeThreadItemType.functionCall) {
          return _ToolCallBubble(
            details: _ResolvedToolCallDetails.fromThread(
              items,
              index,
              matchedToolOutputIndices,
            ),
            onTap: () => onToolTap(item),
          );
        }

        // ツール出力は非表示（ツール呼び出しの状態に含まれる）
        if (item.type == RealtimeThreadItemType.functionCallOutput) {
          return const SizedBox.shrink();
        }

        // メッセージはバルーンで表示
        return _RealtimeChatBubble(item: item);
      },
    );
  }
}

/// ツール呼び出しバッジ
class _ToolCallBubble extends StatelessWidget {
  final _ResolvedToolCallDetails details;
  final VoidCallback onTap;

  const _ToolCallBubble({
    required this.details,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // アバター分のスペース（アシスタントメッセージと行頭を揃える）
          const SizedBox(width: 40), // 16 (radius) * 2 + 8 (spacing)
          _ToolBadge(
            icon: details.badgeIcon,
            label: details.title,
            color: details.statusColor,
            active: details.showSpinner,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _RealtimeChatBubble extends StatelessWidget {
  final RealtimeThreadItem item;

  const _RealtimeChatBubble({required this.item});

  bool get _isUser => item.role == RealtimeThreadItemRole.user;

  bool get _isIncomplete => item.status != RealtimeThreadItemStatus.completed;

  Color get _bubbleColor =>
      _isUser ? AppTheme.primaryColor : AppTheme.surfaceColor;

  Color get _textColor => _isUser ? Colors.white : AppTheme.textPrimary;

  @override
  Widget build(BuildContext context) {
    // メッセージのみバルーン表示（ツールは_ToolPairBubbleで処理）
    final contentWidgets = _buildMessageParts();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
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

  List<Widget> _buildMessageParts() {
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
            style: TextStyle(
              color: _textColor,
              fontSize: 15,
            ),
          ),
        );
      } else if (part is RealtimeThreadAudioPart &&
          (part.transcript?.isNotEmpty ?? false)) {
        widgets.add(
          SelectableText(
            part.transcript!,
            style: TextStyle(
              color: _textColor,
              fontSize: 15,
            ),
          ),
        );
      } else if (part is RealtimeThreadImagePart) {
        widgets.add(
          _AttachmentBadge(
            icon: Icons.image_outlined,
            label: part.imageUrl,
            sublabel: 'detail: ${part.detail}',
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
  final VoidCallback onTap;

  const _ToolBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
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
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 12,
                color: color.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}

Map<int, int> _matchCompletedToolOutputIndices(List<RealtimeThreadItem> items) {
  final matchedToolOutputIndices = <int, int>{};
  final pendingCallIndicesByCallId = <String, List<int>>{};

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.type == RealtimeThreadItemType.functionCall &&
        item.callId != null) {
      pendingCallIndicesByCallId
          .putIfAbsent(item.callId!, () => <int>[])
          .add(i);
    }

    if (item.type == RealtimeThreadItemType.functionCallOutput &&
        item.callId != null) {
      final pendingCalls = pendingCallIndicesByCallId[item.callId!];
      if (pendingCalls != null && pendingCalls.isNotEmpty) {
        matchedToolOutputIndices[pendingCalls.removeAt(0)] = i;
      }
    }
  }

  return matchedToolOutputIndices;
}

_ResolvedToolCallDetails? _resolveToolCallDetails(
  List<RealtimeThreadItem> items,
  String itemId,
) {
  int? targetIndex;
  for (int i = 0; i < items.length; i++) {
    if (items[i].id == itemId) {
      targetIndex = i;
      break;
    }
  }

  if (targetIndex == null) {
    return null;
  }

  final callItem = items[targetIndex];
  if (callItem.type != RealtimeThreadItemType.functionCall) {
    return null;
  }

  final matchedToolOutputIndices = _matchCompletedToolOutputIndices(items);
  return _ResolvedToolCallDetails.fromThread(
    items,
    targetIndex,
    matchedToolOutputIndices,
  );
}

enum _ResolvedToolStage {
  generating,
  executing,
  completed,
  error,
  cancelled,
}

final class _ResolvedToolCallDetails {
  final RealtimeThreadItem callItem;
  final RealtimeThreadItem? outputItem;
  final bool hasCompletedOutput;

  const _ResolvedToolCallDetails({
    required this.callItem,
    required this.outputItem,
    required this.hasCompletedOutput,
  });

  factory _ResolvedToolCallDetails.fromThread(
    List<RealtimeThreadItem> items,
    int targetIndex,
    Map<int, int>? matchedToolOutputIndices,
  ) {
    final callItem = items[targetIndex];
    if (callItem.type != RealtimeThreadItemType.functionCall) {
      throw ArgumentError.value(
        callItem.type,
        'callItem.type',
        'Expected a function call item.',
      );
    }

    final outputIndex = matchedToolOutputIndices?[targetIndex];
    return _ResolvedToolCallDetails(
      callItem: callItem,
      outputItem: outputIndex == null ? null : items[outputIndex],
      hasCompletedOutput: outputIndex != null,
    );
  }

  String get title => callItem.name ?? 'tool_call';

  String? get arguments => callItem.arguments;

  bool get hasArguments => (arguments ?? '').isNotEmpty;

  String get argumentsDisplayText {
    if (hasArguments) {
      return arguments!;
    }
    return switch (stage) {
      _ResolvedToolStage.generating => 'Streaming...',
      _ResolvedToolStage.executing ||
      _ResolvedToolStage.completed ||
      _ResolvedToolStage.error => 'No arguments',
      _ResolvedToolStage.cancelled => 'Cancelled before arguments were completed',
    };
  }

  bool get argumentsPlaceholder => !hasArguments;

  String? get result => outputItem?.output ?? callItem.output;

  bool get hasResult => (result ?? '').isNotEmpty;

  String? get errorMessage =>
      outputItem?.toolErrorMessage ?? callItem.toolErrorMessage;

  String? get resultDisplayText => isError ? (errorMessage ?? result) : result;

  _ResolvedToolStage get stage {
    if (outputItem?.toolOutputDisposition == RealtimeToolOutputDisposition.error) {
      return _ResolvedToolStage.error;
    }
    if (hasCompletedOutput) {
      return _ResolvedToolStage.completed;
    }
    if (callItem.status == RealtimeThreadItemStatus.incomplete) {
      return _ResolvedToolStage.cancelled;
    }
    if (callItem.status == RealtimeThreadItemStatus.completed) {
      return _ResolvedToolStage.executing;
    }
    return _ResolvedToolStage.generating;
  }

  bool get isError => stage == _ResolvedToolStage.error;

  bool get isCancelled => stage == _ResolvedToolStage.cancelled;

  bool get showSpinner =>
      stage == _ResolvedToolStage.generating ||
      stage == _ResolvedToolStage.executing;

  Color get statusColor {
    return switch (stage) {
      _ResolvedToolStage.generating ||
      _ResolvedToolStage.executing => AppTheme.secondaryColor,
      _ResolvedToolStage.completed => Colors.green,
      _ResolvedToolStage.error => Colors.red,
      _ResolvedToolStage.cancelled => Colors.grey,
    };
  }

  IconData get statusIcon {
    return switch (stage) {
      _ResolvedToolStage.generating => Icons.download,
      _ResolvedToolStage.executing => Icons.play_arrow,
      _ResolvedToolStage.completed => Icons.check_circle,
      _ResolvedToolStage.error => Icons.error,
      _ResolvedToolStage.cancelled => Icons.cancel,
    };
  }

  IconData get badgeIcon {
    return switch (stage) {
      _ResolvedToolStage.generating ||
      _ResolvedToolStage.executing ||
      _ResolvedToolStage.completed => Icons.build,
      _ResolvedToolStage.error => Icons.error_outline,
      _ResolvedToolStage.cancelled => Icons.cancel_outlined,
    };
  }

  String get statusText {
    return switch (stage) {
      _ResolvedToolStage.generating => 'Generating arguments...',
      _ResolvedToolStage.executing => 'Executing...',
      _ResolvedToolStage.completed => 'Completed',
      _ResolvedToolStage.error => 'Error',
      _ResolvedToolStage.cancelled => 'Cancelled',
    };
  }
}

class _ToolDetailsSheet extends StatelessWidget {
  final String itemId;
  final List<RealtimeThreadItem> initialItems;
  final RealtimeService? realtimeService;

  const _ToolDetailsSheet({
    required this.itemId,
    required this.initialItems,
    required this.realtimeService,
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
    final details = _resolveToolCallDetails(items, itemId);
    if (details == null) {
      return _buildErrorState(context, 'Tool call not found');
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
                    title: '引数',
                    child: _ToolDetailsCodeBlock(
                      text: details.argumentsDisplayText,
                      isPlaceholder: details.argumentsPlaceholder,
                    ),
                  ),
                  if (details.hasResult) ...[
                    const SizedBox(height: 12),
                    _ToolDetailsSection(
                      title: details.isError ? 'エラー' : '結果',
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
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolDetailsHeader extends StatelessWidget {
  final _ResolvedToolCallDetails details;

  const _ToolDetailsHeader({required this.details});

  @override
  Widget build(BuildContext context) {
    final statusColor = details.statusColor;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            details.statusIcon,
            color: statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            details.title,
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
    final statusColor = details.statusColor;

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
            details.statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details.statusText,
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

  const _ToolDetailsSection({
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

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScrollToBottomButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              '下に戻る',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
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
  final bool enabled;
  final VoidCallback? onSend;

  const _ChatInputShell({
    required this.controller,
    required this.enabled,
    this.onSend,
  });

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
              enabled: enabled,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend?.call() : null,
              decoration: InputDecoration(
                hintText: enabled ? 'メッセージを入力' : '通話中でないと入力できません',
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
            onPressed: enabled ? onSend : null,
            icon: const Icon(
              Icons.send,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  enabled ? AppTheme.primaryColor : AppTheme.textSecondary,
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
