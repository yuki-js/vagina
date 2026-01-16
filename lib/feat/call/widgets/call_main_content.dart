import 'package:flutter/material.dart';
import 'package:vagina/theme/app_theme.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/config/app_config.dart';
import 'package:vagina/feat/call/widgets/audio_level_visualizer.dart';
import 'package:vagina/utils/duration_formatter.dart';

/// 通話メインコンテンツ - アプリロゴ、通話時間、ビジュアライザーを表示
/// call_page.dartから切り出されたコンポーネント
class CallMainContent extends StatelessWidget {
  final bool isCallActive;
  final bool isConnecting;
  final bool isConnected;
  final int callDuration;
  final double inputLevel;
  final bool isMuted;
  final SpeedDial speedDial;

  const CallMainContent({
    super.key,
    required this.isCallActive,
    required this.isConnecting,
    required this.isConnected,
    required this.callDuration,
    required this.inputLevel,
    required this.isMuted,
    required this.speedDial,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = speedDial.isDefault;
    final displayIcon = isDefault 
        ? Icons.headset_mic 
        : null;
    final displayEmoji = !isDefault && speedDial.iconEmoji != null
        ? speedDial.iconEmoji!
        : null;
    final displayName = isDefault
        ? AppConfig.appName
        : speedDial.name;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // アプリロゴ/アイコン (デフォルトはヘッドセット、カスタムは絵文字)
        if (displayIcon != null)
          Icon(
            displayIcon,
            size: 80,
            color: AppTheme.primaryColor,
          )
        else if (displayEmoji != null)
          Text(
            displayEmoji,
            style: const TextStyle(fontSize: 80),
          )
        else
          const Icon(
            Icons.headset_mic,
            size: 80,
            color: AppTheme.primaryColor,
          ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        if (isDefault)
          Text(
            AppConfig.appSubtitle,
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
      ],
    );
  }
}
