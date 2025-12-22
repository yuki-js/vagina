import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../components/call_button.dart';
import '../../services/call_service.dart';

/// Galaxy-style control panel with button grid and call button
class ControlPanel extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final VoidCallback onSettingsPressed;
  final bool hideNavigationButtons;

  const ControlPanel({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    required this.onSettingsPressed,
    this.hideNavigationButtons = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(isMutedProvider);
    final speakerMuted = ref.watch(speakerMutedProvider);
    final isCallActive = ref.watch(isCallActiveProvider);

    // Calculate button width for consistent grid layout
    // 2 columns when hideNavigationButtons is true, 3 columns otherwise
    final numColumns = hideNavigationButtons ? 2 : 3;
    final buttonWidth = (MediaQuery.of(context).size.width - 32 - 48 - 32) / numColumns;
    
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
          // First row: conditionally show navigation buttons
          if (!hideNavigationButtons)
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
                  icon: Icons.settings,
                  label: '設定',
                  onTap: onSettingsPressed,
                  width: buttonWidth,
                ),
              ],
            ),
          if (!hideNavigationButtons) const SizedBox(height: 16),
          // Control row: Speaker, Mute, Interrupt (or Settings when navigation buttons hidden)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: speakerMuted ? Icons.volume_off : Icons.volume_up,
                label: 'スピーカー',
                onTap: () => _handleSpeakerToggle(ref),
                isActive: speakerMuted,
                activeColor: AppTheme.warningColor,
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
              if (!hideNavigationButtons)
                _ControlButton(
                  icon: Icons.front_hand,
                  label: '割込み',
                  onTap: () => _handleInterrupt(ref),
                  enabled: isCallActive,
                  width: buttonWidth,
                ),
            ],
          ),
          if (hideNavigationButtons) const SizedBox(height: 16),
          // Second row when navigation buttons are hidden
          if (hideNavigationButtons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  icon: Icons.front_hand,
                  label: '割込み',
                  onTap: () => _handleInterrupt(ref),
                  enabled: isCallActive,
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

  void _handleSpeakerToggle(WidgetRef ref) {
    ref.read(speakerMutedProvider.notifier).toggle();
    final speakerMuted = ref.read(speakerMutedProvider);
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    audioPlayer.setVolume(speakerMuted ? 0.0 : 1.0);
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
