import '../utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/pip_service.dart';
import '../components/control_button.dart';

/// Galaxy-style control panel with button grid and call button
class ControlPanel extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final bool hideNavigationButtons;

  const ControlPanel({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    this.hideNavigationButtons = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(isMutedProvider);
    final speakerMuted = ref.watch(speakerMutedProvider);
    final isCallActive = ref.watch(isCallActiveProvider);

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
                Expanded(
                  child: ControlButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'チャット',
                    onTap: onChatPressed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ControlButton(
                    icon: Icons.article_outlined,
                    label: 'ノートパッド',
                    onTap: onNotepadPressed,
                  ),
                ),
                // Settings button removed - only accessible from home screen
              ],
            ),
          if (!hideNavigationButtons) const SizedBox(height: 16),
          // Wide layout: 2x2 grid (Speaker/Mute + Interrupt/Settings)
          // Mobile layout: 1 row with Speaker/Mute/Interrupt
          if (hideNavigationButtons) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ControlButton(
                    icon: speakerMuted ? Icons.volume_off : Icons.volume_up,
                    label: 'スピーカー',
                    onTap: () => _handleSpeakerToggle(ref),
                    isActive: speakerMuted,
                    activeColor: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ControlButton(
                    icon: isMuted ? Icons.mic_off : Icons.mic,
                    label: '消音',
                    onTap: () => _handleMuteToggle(ref),
                    isActive: isMuted,
                    activeColor: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ControlButton(
                    icon: Icons.front_hand,
                    label: '割込み',
                    onTap: () => _handleInterrupt(ref),
                    enabled: isCallActive,
                  ),
                ),
                const SizedBox(width: 12),
                // PiP button for mobile only when in standalone call screen
                Expanded(
                  child: (PlatformCompat.isAndroid || PlatformCompat.isIOS)
                      ? ControlButton(
                          icon: Icons.picture_in_picture_alt,
                          label: 'PiP',
                          onTap: () => _handlePiPToggle(context),
                        )
                      : const SizedBox(), // No settings button in standalone call
                ),
              ],
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ControlButton(
                    icon: speakerMuted ? Icons.volume_off : Icons.volume_up,
                    label: 'スピーカー',
                    onTap: () => _handleSpeakerToggle(ref),
                    isActive: speakerMuted,
                    activeColor: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ControlButton(
                    icon: isMuted ? Icons.mic_off : Icons.mic,
                    label: '消音',
                    onTap: () => _handleMuteToggle(ref),
                    isActive: isMuted,
                    activeColor: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ControlButton(
                    icon: Icons.front_hand,
                    label: '割込み',
                    onTap: () => _handleInterrupt(ref),
                    enabled: isCallActive,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          // Main call button - always shows as end call (red) since start is from home screen
          SizedBox(
            height: 72,
            width: 72,
            child: FloatingActionButton(
              heroTag: 'call_fab',
              onPressed: () => _handleCallButton(context, ref),
              backgroundColor: AppTheme.errorColor,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 40,
              ),
            ),
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

  Future<void> _handleCallButton(BuildContext context, WidgetRef ref) async {
    final callService = ref.read(callServiceProvider);
    // Only end call functionality - start is triggered from home screen
    await callService.endCall();

    // Navigate back to home screen after ending call
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePiPToggle(BuildContext context) async {
    if (!PlatformCompat.isAndroid && !PlatformCompat.isIOS) return;

    final pipService = PiPService();
    final isAvailable = await pipService.isPiPAvailable();

    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picture-in-Picture is not available on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      await pipService.enterPiPMode();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enter PiP mode: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
