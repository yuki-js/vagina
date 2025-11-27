import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../call_button.dart';
import 'control_button.dart';

/// Galaxy-style control panel for call screen
class CallControlPanel extends StatelessWidget {
  final bool isMuted;
  final bool speakerMuted;
  final String noiseReduction;
  final bool isCallActive;
  final VoidCallback onChatPressed;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onSettingsPressed;
  final VoidCallback onNoiseReductionToggle;
  final VoidCallback onMuteToggle;
  final VoidCallback onInterruptPressed;
  final VoidCallback onCallButtonPressed;

  const CallControlPanel({
    super.key,
    required this.isMuted,
    required this.speakerMuted,
    required this.noiseReduction,
    required this.isCallActive,
    required this.onChatPressed,
    required this.onSpeakerToggle,
    required this.onSettingsPressed,
    required this.onNoiseReductionToggle,
    required this.onMuteToggle,
    required this.onInterruptPressed,
    required this.onCallButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
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
          // First row: Chat, Speaker, Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ControlButton(
                icon: Icons.chat_bubble_outline,
                label: 'チャット',
                onTap: onChatPressed,
                width: buttonWidth,
              ),
              ControlButton(
                icon: speakerMuted ? Icons.volume_off : Icons.volume_up,
                label: 'スピーカー',
                onTap: onSpeakerToggle,
                isActive: speakerMuted,
                activeColor: AppTheme.warningColor,
                width: buttonWidth,
              ),
              ControlButton(
                icon: Icons.settings,
                label: '設定',
                onTap: onSettingsPressed,
                width: buttonWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Noise reduction, Mute, Interrupt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ControlButton(
                icon: noiseReduction == 'far' ? Icons.noise_aware : Icons.noise_control_off,
                label: noiseReduction == 'far' ? 'ノイズ軽減:遠' : 'ノイズ軽減:近',
                onTap: onNoiseReductionToggle,
                isActive: noiseReduction == 'far',
                activeColor: AppTheme.secondaryColor,
                width: buttonWidth,
              ),
              ControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '消音',
                onTap: onMuteToggle,
                isActive: isMuted,
                activeColor: AppTheme.errorColor,
                width: buttonWidth,
              ),
              ControlButton(
                icon: Icons.front_hand,
                label: '割込み',
                onTap: onInterruptPressed,
                enabled: isCallActive,
                width: buttonWidth,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Main call button
          CallButton(
            isCallActive: isCallActive,
            size: 72,
            onPressed: onCallButtonPressed,
          ),
        ],
      ),
    );
  }
}
