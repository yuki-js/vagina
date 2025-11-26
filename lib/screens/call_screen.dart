import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/call_service.dart';
import '../components/components.dart';
import 'settings_screen.dart';

/// Main call screen with mute, disconnect, and settings buttons
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

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
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

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
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

  bool get _isCallActive =>
      _callState == CallState.connecting || _callState == CallState.connected;

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMutedProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Stack(
            children: [
              // Settings button (top right)
              Positioned(
                top: 16,
                right: 16,
                child: CircularIconButton(
                  icon: Icons.settings,
                  size: 48,
                  backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
                  onPressed: _openSettings,
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo/title
                    const AppHeader(),

                    const SizedBox(height: 32),

                    // Audio level visualizer and status (when call active)
                    if (_isCallActive) ...[
                      AudioLevelVisualizer(
                        level: _inputLevel,
                        isMuted: isMuted,
                        isConnected: _callState == CallState.connected,
                      ),
                      const SizedBox(height: 16),
                      StatusIndicator(
                        isMuted: isMuted,
                        duration: _formatDuration(_callDuration),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Connection status (when connecting)
                    if (_callState == CallState.connecting) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '接続中...',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    const SizedBox(height: 48),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mute button
                        CircularIconButton(
                          icon: isMuted ? Icons.mic_off : Icons.mic,
                          size: 64,
                          isActive: isMuted,
                          activeBackgroundColor: AppTheme.errorColor,
                          onPressed: _handleMuteButton,
                        ),

                        const SizedBox(width: 32),

                        // Call button (start/end call)
                        CallButton(
                          isCallActive: _isCallActive,
                          size: 80,
                          onPressed: _handleCallButton,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
