import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/widgets/realtime_thread_renderer.dart';

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
    _isConnected = service?.connectionState.isConnected ?? false;

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

    _connectionStateSubscription = service.connectionStateUpdates.listen((
      state,
    ) {
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
      builder: (context) => RealtimeThreadToolDetailsSheet(
        itemId: item.id,
        initialItems: _items,
        realtimeService: _realtimeService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _ChatHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
          title: l10n.callChatTitle,
          backLabel: l10n.callChatBackToCall,
        ),
        Expanded(
          child: _items.isEmpty
              ? _ChatEmptyState(
                  title: l10n.callChatEmptyTitle,
                  message: l10n.callChatEmptyMessage,
                )
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
                        RealtimeThreadView(
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
          enabledHintText: l10n.callChatInputHintEnabled,
          disabledHintText: l10n.callChatInputHintDisabled,
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
  final String title;
  final String backLabel;

  const _ChatHeader({
    required this.onBackPressed,
    required this.hideBackButton,
    required this.title,
    required this.backLabel,
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
                title,
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
                    backLabel,
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

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScrollToBottomButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              l10n.callChatScrollToBottom,
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
  final String title;
  final String message;

  const _ChatEmptyState({required this.title, required this.message});

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
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
  final String enabledHintText;
  final String disabledHintText;

  const _ChatInputShell({
    required this.controller,
    required this.enabled,
    this.onSend,
    required this.enabledHintText,
    required this.disabledHintText,
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
                hintText: enabled ? enabledHintText : disabledHintText,
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
            icon: const Icon(Icons.send, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: enabled
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
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
