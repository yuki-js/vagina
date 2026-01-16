import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../components/chat_bubble.dart';
import '../../components/chat_input.dart';
import '../../components/chat_empty_state.dart';
import '../../components/call/chat_header.dart';
import '../../components/call/scroll_to_bottom_button.dart';

/// Chat page widget - displays chat history and input
class ChatPage extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const ChatPage({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
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

  @override
  Widget build(BuildContext context) {
    final chatMessagesAsync = ref.watch(chatMessagesProvider);
    final isCallActive = ref.watch(isCallActiveProvider);

    return Column(
      children: [
        // Header
        ChatHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
        ),

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
                  _scrollController
                      .jumpTo(_scrollController.position.maxScrollExtent);
                }
              });

              return Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        child: ScrollToBottomButton(onPressed: _scrollToBottom),
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
