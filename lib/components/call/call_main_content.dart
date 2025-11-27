import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../audio_level_visualizer.dart';

/// Main content display for call screen showing app logo and call status
class CallMainContent extends StatelessWidget {
  final bool isMuted;
  final bool isConnecting;
  final bool isCallActive;
  final bool isConnected;
  final int callDuration;
  final double inputLevel;

  const CallMainContent({
    super.key,
    required this.isMuted,
    required this.isConnecting,
    required this.isCallActive,
    required this.isConnected,
    required this.callDuration,
    required this.inputLevel,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
        if (isCallActive) ...[
          Text(
            _formatDuration(callDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Audio level visualizer
          AudioLevelVisualizer(
            level: inputLevel,
            isMuted: isMuted,
            isConnected: isConnected,
            height: 60,
          ),
        ],

        // Connection status (when connecting)
        if (isConnecting) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );
  }
}
