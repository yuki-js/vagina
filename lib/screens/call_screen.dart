import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/call_service.dart';
import '../components/components.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

/// Main call screen with Galaxy-style UI
/// Features: swipe left or chat button to access chat UI
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  StreamSubscription<CallState>? _stateSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<int>? _durationSubscription;
  StreamSubscription<String>? _errorSubscription;

  CallState _callState = CallState.idle;
  double _inputLevel = 0.0;
  int _callDuration = 0;
  bool _subscriptionsInitialized = false;

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
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

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  bool get _isCallActive =>
      _callState == CallState.connecting || _callState == CallState.connected;

  String get _statusText {
    switch (_callState) {
      case CallState.idle:
        return 'タップして通話開始';
      case CallState.connecting:
        return '接続中...';
      case CallState.connected:
        return '通話中';
      case CallState.error:
        return 'エラー';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Setup subscriptions on first build (safe to use ref here)
    _setupSubscriptions();
    
    final isMuted = ref.watch(isMutedProvider);

    return GestureDetector(
      // Swipe left to open chat
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          _openChat();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: Column(
              children: [
                // Top status bar
                _buildTopBar(),
                
                // Main content area (expandable)
                Expanded(
                  child: _buildMainContent(isMuted),
                ),
                
                // Galaxy-style control panel at bottom
                _buildControlPanel(isMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isCallActive ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
                  size: 12,
                  color: _isCallActive ? AppTheme.successColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isCallActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
            onPressed: _openSettings,
          ),
        ],
      ),
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
        color: AppTheme.surfaceColor.withOpacity(0.8),
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
                onTap: _openChat,
              ),
              // Placeholder for future feature
              _buildControlButton(
                icon: Icons.history,
                label: '履歴',
                onTap: () {},
                enabled: false,
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
              // Speaker (placeholder)
              _buildControlButton(
                icon: Icons.volume_up,
                label: 'スピーカー',
                onTap: () {},
                enabled: false,
              ),
              // Mute button
              _buildControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: isMuted ? 'ミュート中' : '消音',
                onTap: _handleMuteButton,
                isActive: isMuted,
                activeColor: AppTheme.errorColor,
              ),
              // Keypad (placeholder)
              _buildControlButton(
                icon: Icons.dialpad,
                label: 'キーパッド',
                onTap: () {},
                enabled: false,
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
        ? AppTheme.textSecondary.withOpacity(0.3)
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
                  ? (activeColor ?? AppTheme.primaryColor).withOpacity(0.2)
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
}
