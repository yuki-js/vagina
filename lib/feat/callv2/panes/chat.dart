import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/callv2/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/realtime_service.dart';

class ChatPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;
  final CallService? callService;

  const ChatPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
    this.callService,
  });

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final TextEditingController _textController = TextEditingController();
  StreamSubscription<RealtimeThread>? _threadSubscription;
  List<RealtimeThreadItem> _items = const <RealtimeThreadItem>[];

  RealtimeService? get _realtimeService => widget.callService?.realtimeService;

  @override
  void initState() {
    super.initState();
    _bindRealtimeService(_realtimeService);
  }

  @override
  void didUpdateWidget(covariant ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callService == widget.callService) {
      return;
    }
    _bindRealtimeService(_realtimeService);
  }

  void _bindRealtimeService(RealtimeService? service) {
    _threadSubscription?.cancel();
    _threadSubscription = null;

    if (service == null) {
      setState(() {
        _items = const <RealtimeThreadItem>[];
      });
      return;
    }

    _items = service.thread.items;
    _threadSubscription = service.threadUpdates.listen((thread) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = thread.items;
      });
    });
  }

  @override
  void dispose() {
    _threadSubscription?.cancel();
    _textController.dispose();
    super.dispose();
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
              : _ChatMessageList(items: _items),
        ),
        _ChatInputShell(
          controller: _textController,
          enabled: _realtimeService?.isConnected ?? false,
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

    final service = _realtimeService;
    if (service == null || !service.isConnected) {
      return;
    }

    // Send text to realtime service
    service.sendText(text);
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

  const _ChatMessageList({required this.items});

  @override
  Widget build(BuildContext context) {
    // 出力を同じcallIdの最初の未解決tool callへ順番に対応付ける。
    // callIdの重複があっても、1つのtool outputで複数のtool callを
    // 完了扱いにしないための one-to-one マッチング。
    final matchedCallIndices = <int>{};
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
          item.callId != null &&
          item.status == RealtimeThreadItemStatus.completed) {
        final pendingCalls = pendingCallIndicesByCallId[item.callId!];
        if (pendingCalls != null && pendingCalls.isNotEmpty) {
          matchedCallIndices.add(pendingCalls.removeAt(0));
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // ツール呼び出しはバッジで表示
        if (item.type == RealtimeThreadItemType.functionCall) {
          return _ToolCallBubble(
            item: item,
            hasCompletedOutput: matchedCallIndices.contains(index),
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
  final RealtimeThreadItem item;
  final bool hasCompletedOutput;

  const _ToolCallBubble({
    required this.item,
    required this.hasCompletedOutput,
  });

  bool get _isActive {
    // 出力が完了していればツール実行完了
    if (hasCompletedOutput) {
      return false;
    }
    // incompleteならエラー/キャンセル（非アクティブ）
    if (item.status == RealtimeThreadItemStatus.incomplete) {
      return false;
    }
    // それ以外は実行中（引数構築中 or ツール実行中）
    return true;
  }

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
            icon: Icons.build,
            label: item.name ?? 'tool_call',
            active: _isActive,
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
  final bool active;

  const _ToolBadge({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.secondaryColor;

    return Container(
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
