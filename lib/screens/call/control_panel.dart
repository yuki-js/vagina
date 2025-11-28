import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../components/call_button.dart';
import '../../services/call_service.dart';

/// Galaxy-style control panel with 2x3 button grid and call button
class ControlPanel extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final VoidCallback onSettingsPressed;

  const ControlPanel({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(isMutedProvider);
    final doubleSpeed = ref.watch(doubleSpeedProvider);
    final noiseReduction = ref.watch(noiseReductionProvider);
    final isCallActive = ref.watch(isCallActiveProvider);

    // Calculate button width for consistent grid layout (now 4 columns)
    final buttonWidth = (MediaQuery.of(context).size.width - 32 - 48 - 32) / 4;
    
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
          // First row: Chat, Artifact, Double Speed, Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: Icons.chat_bubble_outline,
                label: 'チャット',
                onTap: onChatPressed,
                width: buttonWidth,
              ),
              _ControlButton(
                icon: Icons.article_outlined,
                label: 'ノートパッド',
                onTap: onNotepadPressed,
                width: buttonWidth,
              ),
              _ControlButton(
                icon: Icons.speed,
                label: doubleSpeed ? '2倍速' : '等速',
                onTap: () => _handleDoubleSpeedToggle(ref),
                isActive: doubleSpeed,
                activeColor: AppTheme.secondaryColor,
                width: buttonWidth,
              ),
              _ControlButton(
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
              _ControlButton(
                icon: noiseReduction == 'far' ? Icons.noise_aware : Icons.noise_control_off,
                label: noiseReduction == 'far' ? 'ノイズ軽減:遠' : 'ノイズ軽減:近',
                onTap: () => _handleNoiseReductionToggle(ref),
                isActive: noiseReduction == 'far',
                activeColor: AppTheme.secondaryColor,
                width: buttonWidth,
              ),
              _ControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: '消音',
                onTap: () => _handleMuteToggle(ref),
                isActive: isMuted,
                activeColor: AppTheme.errorColor,
                width: buttonWidth,
              ),
              _ControlButton(
                icon: Icons.front_hand,
                label: '割込み',
                onTap: () => _handleInterrupt(ref),
                enabled: isCallActive,
                width: buttonWidth,
              ),
              // Empty spacer for alignment
              SizedBox(width: buttonWidth),
            ],
          ),
          const SizedBox(height: 24),
          // Main call button
          CallButton(
            isCallActive: isCallActive,
            size: 72,
            onPressed: () => _handleCallButton(ref),
          ),
        ],
      ),
    );
  }

  void _handleDoubleSpeedToggle(WidgetRef ref) {
    ref.read(doubleSpeedProvider.notifier).toggle();
    final doubleSpeed = ref.read(doubleSpeedProvider);
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    audioPlayer.setSpeed(doubleSpeed ? 2.0 : 1.0);
  }

  void _handleNoiseReductionToggle(WidgetRef ref) {
    ref.read(noiseReductionProvider.notifier).toggle();
    final noiseReduction = ref.read(noiseReductionProvider);
    final apiClient = ref.read(realtimeApiClientProvider);
    apiClient.setNoiseReduction(noiseReduction);
    
    // If connected, update session config
    final isCallActive = ref.read(isCallActiveProvider);
    if (isCallActive) {
      apiClient.updateSessionConfig();
    }
  }

  void _handleMuteToggle(WidgetRef ref) {
    final callService = ref.read(callServiceProvider);
    ref.read(isMutedProvider.notifier).toggle();
    final isMuted = ref.read(isMutedProvider);
    callService.setMuted(isMuted);
  }

  void _handleInterrupt(WidgetRef ref) {
    final isCallActive = ref.read(isCallActiveProvider);
    if (!isCallActive) return;
    
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    final apiClient = ref.read(realtimeApiClientProvider);
    
    audioPlayer.stop();
    apiClient.cancelResponse();
  }

  Future<void> _handleCallButton(WidgetRef ref) async {
    final callService = ref.read(callServiceProvider);
    final callStateAsync = ref.read(callStateProvider);
    final callState = callStateAsync.value ?? CallState.idle;
    
    if (callState == CallState.idle || callState == CallState.error) {
      await callService.startCall();
    } else {
      await callService.endCall();
    }
  }
}

/// Individual control button widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double width;
  final bool enabled;
  final bool isActive;
  final Color? activeColor;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.width,
    this.enabled = true,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
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
}
