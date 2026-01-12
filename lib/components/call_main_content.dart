import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'audio_level_visualizer.dart';
import '../utils/duration_formatter.dart';

/// 通話メインコンテンツ - アプリロゴ、通話時間、ビジュアライザーを表示
/// call_page.dartから切り出されたコンポーネント
class CallMainContent extends StatelessWidget {
  final bool isCallActive;
  final bool isConnecting;
  final bool isConnected;
  final int callDuration;
  final double inputLevel;
  final bool isMuted;
  final String assistantName;

  const CallMainContent({
    super.key,
    required this.isCallActive,
    required this.isConnecting,
    required this.isConnected,
    required this.callDuration,
    required this.inputLevel,
    required this.isMuted,
    required this.assistantName,
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
        
        // アシスタント名表示（デフォルトでない場合のみ、さりげなく表示）
        if (isCallActive && assistantName != 'VAGINA') ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              assistantName,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
