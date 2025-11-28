import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import 'chat_bubble.dart';
import 'chat_input.dart';
import 'chat_empty_state.dart';

/// Chat page widget - displays chat history and input
class ChatPage extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;

  const ChatPage({
    super.key,
    required this.onBackPressed,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isAtBottom = currentScroll >= maxScroll - 50;
    final shouldShowScrollButton = !isAtBottom;
    
    if (isAtBottom != _isAtBottom || shouldShowScrollButton != _showScrollToBottom) {
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

  @override
  Widget build(BuildContext context) {
    final chatMessagesAsync = ref.watch(chatMessagesProvider);
    final isCallActive = ref.watch(isCallActiveProvider);

    return Column(
      children: [
        // Header
        _ChatHeader(onBackPressed: widget.onBackPressed),

        // Chat messages
        Expanded(
          child: chatMessagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return ChatEmptyState(isConnected: isCallActive);
              }
              
              // Smart auto-scroll: only scroll if user is already at bottom
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_isAtBottom && _scrollController.hasClients) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });
              
              return Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ChatBubble(message: message);
                    },
                  ),
                  // Floating "scroll to bottom" bar
                  if (_showScrollToBottom)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _ScrollToBottomButton(onPressed: _scrollToBottom),
                      ),
                    ),
                ],
              );
            },
            loading: () => const ChatEmptyState(isConnected: false),
            error: (_, __) => const Center(
              child: Text(
                'チャットの読み込みに失敗しました',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ),
        ),

        // Input area
        ChatInput(isConnected: isCallActive),
      ],
    );
  }
}

/// Chat header with back button
class _ChatHeader extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _ChatHeader({required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackPressed,
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                Text(
                  '通話画面',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
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
          const SizedBox(width: 80), // Balance for the back button
        ],
      ),
    );
  }
}

/// Scroll to bottom button
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
