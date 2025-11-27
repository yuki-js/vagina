import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/call_service.dart';
import '../components/components.dart';
import 'settings_screen.dart';

/// Main home screen with PageView for swipe navigation between call and chat
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Page indices for navigation
  static const int _callPageIndex = 0;
  static const int _chatPageIndex = 1;
  
  late final PageController _pageController;
  
  // Call state
  StreamSubscription<CallState>? _stateSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<int>? _durationSubscription;
  StreamSubscription<String>? _errorSubscription;

  CallState _callState = CallState.idle;
  double _inputLevel = 0.0;
  int _callDuration = 0;
  bool _subscriptionsInitialized = false;
  
  /// Noise reduction type: 'near' (default) or 'far'
  String _noiseReduction = 'near';
  
  /// Speaker mute state
  bool _speakerMuted = false;
  
  // Chat state
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;
  
  /// Current page index (0 = call, 1 = chat)
  int _currentPageIndex = _callPageIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _callPageIndex);
    _pageController.addListener(_onPageChanged);
    _scrollController.addListener(_onScrollChanged);
  }
  
  void _onPageChanged() {
    if (_pageController.hasClients) {
      final page = _pageController.page?.round() ?? _callPageIndex;
      if (page != _currentPageIndex) {
        setState(() {
          _currentPageIndex = page;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _stateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    _textController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _focusNode.dispose();
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

  void _setupSubscriptions() {
    if (_subscriptionsInitialized) return;
    _subscriptionsInitialized = true;

    final callService = ref.read(callServiceProvider);

    _stateSubscription = callService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _callState = state);
      }
    });

    _amplitudeSubscription = callService.amplitudeStream.listen((level) {
      if (mounted) {
        setState(() => _inputLevel = level);
      }
    });

    _durationSubscription = callService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _callDuration = duration);
      }
    });

    _errorSubscription = callService.errorStream.listen((error) {
      if (mounted) {
        _showSnackBar(error, isError: true);
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleCallButton() async {
    final callService = ref.read(callServiceProvider);
    
    if (_callState == CallState.idle || _callState == CallState.error) {
      await callService.startCall();
    } else {
      await callService.endCall();
    }
  }

  void _handleMuteButton() {
    final callService = ref.read(callServiceProvider);
    ref.read(isMutedProvider.notifier).toggle();
    final isMuted = ref.read(isMutedProvider);
    callService.setMuted(isMuted);
  }

  void _handleSpeakerMuteToggle() {
    setState(() => _speakerMuted = !_speakerMuted);
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    audioPlayer.setVolume(_speakerMuted ? 0.0 : 1.0);
  }

  void _handleInterruptButton() {
    if (!_isCallActive) return;
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    final apiClient = ref.read(realtimeApiClientProvider);
    audioPlayer.stop();
    apiClient.cancelResponse();
  }

  void _handleNoiseReductionToggle() {
    setState(() => _noiseReduction = _noiseReduction == 'near' ? 'far' : 'near');
    final apiClient = ref.read(realtimeApiClientProvider);
    apiClient.setNoiseReduction(_noiseReduction);
    if (_isCallActive) {
      apiClient.updateSessionConfig();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _goToChat() {
    _pageController.animateToPage(
      _chatPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToCall() {
    _pageController.animateToPage(
      _callPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _isCallActive =>
      _callState == CallState.connecting || _callState == CallState.connected;

  void _handleBackButton() {
    if (_currentPageIndex == _chatPageIndex) {
      _goToCall();
    } else if (_isCallActive) {
      _showSnackBar('通話を終了してからアプリを閉じてください', isError: true);
    }
  }

  bool get _canPop {
    if (_currentPageIndex == _chatPageIndex) {
      return false;
    }
    return !_isCallActive;
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    final callService = ref.read(callServiceProvider);
    callService.sendTextMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _setupSubscriptions();
    final isMuted = ref.watch(isMutedProvider);

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: PageView(
              controller: _pageController,
              children: [
                _buildCallPage(isMuted),
                _buildChatPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallPage(bool isMuted) {
    return Column(
      children: [
        Expanded(
          child: CallMainContent(
            isMuted: isMuted,
            isConnecting: _callState == CallState.connecting,
            isCallActive: _isCallActive,
            isConnected: _callState == CallState.connected,
            callDuration: _callDuration,
            inputLevel: _inputLevel,
          ),
        ),
        CallControlPanel(
          isMuted: isMuted,
          speakerMuted: _speakerMuted,
          noiseReduction: _noiseReduction,
          isCallActive: _isCallActive,
          onChatPressed: _goToChat,
          onSpeakerToggle: _handleSpeakerMuteToggle,
          onSettingsPressed: _openSettings,
          onNoiseReductionToggle: _handleNoiseReductionToggle,
          onMuteToggle: _handleMuteButton,
          onInterruptPressed: _handleInterruptButton,
          onCallButtonPressed: _handleCallButton,
        ),
      ],
    );
  }

  Widget _buildChatPage() {
    final chatMessagesAsync = ref.watch(chatMessagesProvider);
    final callService = ref.read(callServiceProvider);
    final isConnected = callService.isCallActive;

    return Column(
      children: [
        _buildChatHeader(),
        Expanded(child: _buildChatContent(chatMessagesAsync, isConnected)),
        _buildChatInput(isConnected),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goToCall,
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                Text(
                  '通話画面',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildChatContent(AsyncValue<List<dynamic>> chatMessagesAsync, bool isConnected) {
    return chatMessagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return EmptyChatState(isConnected: isConnected);
        }
        
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
              itemBuilder: (context, index) => ChatBubble(message: messages[index]),
            ),
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
      loading: () => const EmptyChatState(isConnected: false),
      error: (error, stackTrace) => const Center(
        child: Text(
          'チャットの読み込みに失敗しました',
          style: TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }

  Widget _buildChatInput(bool isConnected) {
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
              controller: _textController,
              focusNode: _focusNode,
              enabled: isConnected,
              decoration: InputDecoration(
                hintText: isConnected ? 'メッセージを入力...' : '通話中でないと入力できません',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.backgroundStart,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: isConnected ? _sendMessage : null,
            backgroundColor: isConnected ? AppTheme.primaryColor : AppTheme.textSecondary,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
