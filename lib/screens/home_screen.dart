import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/call_service.dart';
import '../models/chat_message.dart';
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
  bool _isAtBottom = true; // Track if user is at bottom for smart auto-scroll
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
    final isAtBottom = currentScroll >= maxScroll - 50; // 50px threshold
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
        setState(() {
          _callState = state;
        });
      }
    });

    _amplitudeSubscription = callService.amplitudeStream.listen((level) {
      if (mounted) {
        setState(() {
          _inputLevel = level;
        });
      }
    });

    _durationSubscription = callService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _callDuration = duration;
        });
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
    setState(() {
      _speakerMuted = !_speakerMuted;
    });
    
    // Set speaker volume
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    audioPlayer.setVolume(_speakerMuted ? 0.0 : 1.0);
  }

  void _handleInterruptButton() {
    if (!_isCallActive) return;
    
    // Stop current audio playback and cancel response
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    final apiClient = ref.read(realtimeApiClientProvider);
    
    audioPlayer.stop();
    apiClient.cancelResponse();
  }

  void _handleNoiseReductionToggle() {
    setState(() {
      _noiseReduction = _noiseReduction == 'near' ? 'far' : 'near';
    });
    
    // Update the API client's noise reduction setting
    final apiClient = ref.read(realtimeApiClientProvider);
    apiClient.setNoiseReduction(_noiseReduction);
    
    // If connected, update session config
    if (_isCallActive) {
      apiClient.updateSessionConfig();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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

  /// Handles back button press
  /// - From chat page: go back to call page
  /// - From call page with active call: show snackbar prompting to end call
  /// - From call page without active call: allow exit
  void _handleBackButton() {
    if (_currentPageIndex == _chatPageIndex) {
      // On chat page - go back to call page
      _goToCall();
    } else if (_isCallActive) {
      // On call page with active call - show snackbar prompting to end call
      _showSnackBar('通話を終了してからアプリを閉じてください', isError: true);
    }
    // On call page without active call - do nothing (handled by canPop)
  }

  /// Determines if the current route can be popped (app can exit)
  /// Returns false to prevent pop when:
  /// - On chat page (should navigate to call page instead)
  /// - On call page with active call (prevent accidental exit during call)
  bool get _canPop {
    if (_currentPageIndex == _chatPageIndex) {
      // On chat page - prevent pop, will navigate to call page
      return false;
    }
    // On call page - allow pop only if call is not active
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
                // Page 0: Call Screen
                _buildCallPage(isMuted),
                // Page 1: Chat Screen
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
        // Main content area (expandable)
        Expanded(
          child: _buildMainContent(isMuted),
        ),
        
        // Galaxy-style control panel at bottom
        _buildControlPanel(isMuted),
      ],
    );
  }

  Widget _buildMainContent(bool isMuted) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App logo/title
        const Icon(
          Icons.headset_mic,
          size: 80,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        const Text(
          'VAGINA',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Voice AGI Native App',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        
        const SizedBox(height: 32),

        // Duration display (when call active)
        if (_isCallActive) ...[
          Text(
            _formatDuration(_callDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Audio level visualizer
          AudioLevelVisualizer(
            level: _inputLevel,
            isMuted: isMuted,
            isConnected: _callState == CallState.connected,
            height: 60,
          ),
        ],

        // Connection status (when connecting)
        if (_callState == CallState.connecting) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );
  }

  Widget _buildControlPanel(bool isMuted) {
    // Calculate button width for consistent grid layout
    final buttonWidth = (MediaQuery.of(context).size.width - 32 - 40 - 32) / 3;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2x3 button grid (Galaxy style) with fixed widths
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Chat button
              _buildControlButton(
                icon: Icons.chat_bubble_outline,
                label: 'チャット',
                onTap: _goToChat,
                width: buttonWidth,
              ),
              // Speaker mute button
              _buildControlButton(
                icon: _speakerMuted ? Icons.volume_off : Icons.volume_up,
                label: 'スピーカー',
                onTap: _handleSpeakerMuteToggle,
                isActive: _speakerMuted,
                activeColor: AppTheme.warningColor,
                width: buttonWidth,
              ),
              // Settings
              _buildControlButton(
                icon: Icons.settings,
                label: '設定',
                onTap: _openSettings,
                width: buttonWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Noise reduction toggle (far/near)
              _buildControlButton(
                icon: _noiseReduction == 'far' ? Icons.noise_aware : Icons.noise_control_off,
                label: 'ノイズ軽減',
                onTap: _handleNoiseReductionToggle,
                isActive: _noiseReduction == 'far',
                activeColor: AppTheme.secondaryColor,
                width: buttonWidth,
              ),
              // Mute button
              _buildControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '消音',
                onTap: _handleMuteButton,
                isActive: isMuted,
                activeColor: AppTheme.errorColor,
                width: buttonWidth,
              ),
              // Interrupt button (stop current response)
              _buildControlButton(
                icon: Icons.front_hand,
                label: '割込み',
                onTap: _handleInterruptButton,
                enabled: _isCallActive,
                width: buttonWidth,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Main call button
          CallButton(
            isCallActive: _isCallActive,
            size: 72,
            onPressed: _handleCallButton,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double width,
    bool enabled = true,
    bool isActive = false,
    Color? activeColor,
  }) {
    final color = !enabled 
        ? AppTheme.textSecondary.withValues(alpha: 0.3)
        : isActive 
            ? (activeColor ?? AppTheme.primaryColor)
            : AppTheme.textSecondary;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isActive 
                    ? (activeColor ?? AppTheme.primaryColor).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPage() {
    final chatMessagesAsync = ref.watch(chatMessagesProvider);
    final callService = ref.read(callServiceProvider);
    final isConnected = callService.isCallActive;

    return Column(
      children: [
        // Simple header with back gesture hint
        Padding(
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
        ),

        // Chat messages
        Expanded(
          child: chatMessagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                // Friendly empty state message
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
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
                          isConnected 
                              ? '話しかけるか、下のテキストボックスからメッセージを送信してください'
                              : '通話を開始すると、ここに会話が表示されます',
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
                      return _ChatBubble(message: message);
                    },
                  ),
                  // Floating "scroll to bottom" bar
                  if (_showScrollToBottom)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _scrollToBottom,
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
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
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
                  ],
                ),
              ),
            ),
            error: (_, __) => const Center(
              child: Text(
                'チャットの読み込みに失敗しました',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ),
        ),

        // Input area
        Container(
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: isConnected ? _sendMessage : null,
                backgroundColor: isConnected 
                    ? AppTheme.primaryColor 
                    : AppTheme.textSecondary,
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual chat bubble widget
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  void _showToolDetails(BuildContext context) {
    if (message.toolCall == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    message.toolCall!.name,
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
                message.toolCall!.arguments,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                message.toolCall!.result,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';
    
    // Tool message style - inline badge with reduced padding
    if (isTool) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: () => _showToolDetails(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.build, size: 12, color: AppTheme.secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        message.toolCall?.name ?? 'ツール',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right, 
                        size: 12, 
                        color: AppTheme.secondaryColor.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser 
                    ? AppTheme.primaryColor 
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.content,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (!message.isComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
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
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.successColor,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
