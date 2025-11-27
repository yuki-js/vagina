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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToCall() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _isCallActive =>
      _callState == CallState.connecting || _callState == CallState.connected;

  // Chat methods
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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

    return Scaffold(
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
          // 2x3 button grid (Galaxy style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Chat button
              _buildControlButton(
                icon: Icons.chat_bubble_outline,
                label: 'チャット',
                onTap: _goToChat,
              ),
              // Speaker mute button
              _buildControlButton(
                icon: _speakerMuted ? Icons.volume_off : Icons.volume_up,
                label: _speakerMuted ? 'スピーカーOFF' : 'スピーカー',
                onTap: _handleSpeakerMuteToggle,
                isActive: _speakerMuted,
                activeColor: AppTheme.warningColor,
              ),
              // Settings
              _buildControlButton(
                icon: Icons.settings,
                label: '設定',
                onTap: _openSettings,
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
                label: _noiseReduction == 'far' ? 'ノイズ軽減:遠' : 'ノイズ軽減:近',
                onTap: _handleNoiseReductionToggle,
                isActive: _noiseReduction == 'far',
                activeColor: AppTheme.secondaryColor,
              ),
              // Mute button
              _buildControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: isMuted ? 'ミュート中' : '消音',
                onTap: _handleMuteButton,
                isActive: isMuted,
                activeColor: AppTheme.errorColor,
              ),
              // Interrupt button (stop current response)
              _buildControlButton(
                icon: Icons.front_hand,
                label: '会話に割込み',
                onTap: _handleInterruptButton,
                enabled: _isCallActive,
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
          ),
        ],
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
                return const Center(
                  child: Text(
                    '通話を開始すると会話がここに表示されます',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              
              // Auto-scroll when new messages arrive
              _scrollToBottom();
              
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _ChatBubble(message: message);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
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

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    
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
                  Text(
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
