import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/call_service.dart';
import '../../components/audio_level_visualizer.dart';
import '../../utils/duration_formatter.dart';
import '../../models/speed_dial.dart';
import 'control_panel.dart';

/// 通話ページウィジェット - 通話UIとコントロールを表示
class CallPage extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final VoidCallback onSettingsPressed;
  final bool hideNavigationButtons;

  const CallPage({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    required this.onSettingsPressed,
    this.hideNavigationButtons = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callStateAsync = ref.watch(callStateProvider);
    final amplitudeAsync = ref.watch(amplitudeProvider);
    final durationAsync = ref.watch(durationProvider);
    final isMuted = ref.watch(isMutedProvider);
    final currentSpeedDial = ref.watch(currentSpeedDialProvider);

    final isCallActive = ref.watch(isCallActiveProvider);
    final callState = callStateAsync.value;
    final amplitude = amplitudeAsync.value ?? 0.0;
    final duration = durationAsync.value ?? 0;

    return Column(
      children: [
        // メインコンテンツエリア（拡張可能）
        Expanded(
          child: _CallMainContent(
            isCallActive: isCallActive,
            isConnecting: callState == CallState.connecting,
            isConnected: callState == CallState.connected,
            callDuration: duration,
            inputLevel: amplitude,
            isMuted: isMuted,
            speedDial: currentSpeedDial,
          ),
        ),

        // Galaxy風コントロールパネル（下部）
        ControlPanel(
          onChatPressed: onChatPressed,
          onNotepadPressed: onNotepadPressed,
          onSettingsPressed: onSettingsPressed,
          hideNavigationButtons: hideNavigationButtons,
        ),
      ],
    );
  }
}

/// メインコンテンツエリア - アプリロゴ、通話時間、ビジュアライザーを表示
class _CallMainContent extends StatelessWidget {
  final bool isCallActive;
  final bool isConnecting;
  final bool isConnected;
  final int callDuration;
  final double inputLevel;
  final bool isMuted;
  final SpeedDial? speedDial;

  const _CallMainContent({
    required this.isCallActive,
    required this.isConnecting,
    required this.isConnected,
    required this.callDuration,
    required this.inputLevel,
    required this.isMuted,
    this.speedDial,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // アプリロゴ/タイトル
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
          'Voice AGI Notepad Agent',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 32),

        // 通話時間表示（通話中のみ）
        if (isCallActive) ...[
          Text(
            DurationFormatter.formatMinutesSeconds(callDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // 音声レベルビジュアライザー
          AudioLevelVisualizer(
            level: inputLevel,
            isMuted: isMuted,
            isConnected: isConnected,
            height: 60,
          ),
        ],

        // 接続中表示
        if (isConnecting) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ],
        
        // スピードダイヤル情報（通話中のみ、さりげなく表示）
        if (isCallActive && speedDial != null) ...[
          const SizedBox(height: 24),
          _SpeedDialIndicator(speedDial: speedDial!),
        ],
      ],
    );
  }
}

/// スピードダイヤルインジケーター - 現在使用中のスピードダイヤルをさりげなく表示
class _SpeedDialIndicator extends StatelessWidget {
  final SpeedDial speedDial;
  
  const _SpeedDialIndicator({required this.speedDial});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (speedDial.iconEmoji != null) ...[
            Text(
              speedDial.iconEmoji!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            speedDial.name,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
