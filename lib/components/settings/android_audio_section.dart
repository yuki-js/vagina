import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../theme/app_theme.dart';
import '../../screens/settings/providers.dart';
import '../../models/android_audio_config.dart';
import '../../components/settings_card.dart';

/// Android audio settings section widget
class AndroidAudioSection extends ConsumerWidget {
  const AndroidAudioSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConfig = ref.watch(androidAudioConfigProvider);
    
    return asyncConfig.when(
      loading: () => const SettingsCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SettingsCard(
        child: Text('エラー: $error', style: const TextStyle(color: AppTheme.errorColor)),
      ),
      data: (config) => SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio source dropdown
            const Text(
              'オーディオソース',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'マイク入力に使用するオーディオソースを選択します',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AndroidAudioSource>(
              value: config.audioSource,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppTheme.lightSurfaceColor,
              items: AndroidAudioSource.values.map((source) {
                return DropdownMenuItem(
                  value: source,
                  child: Text(
                    AndroidAudioConfig.audioSourceDisplayNames[source] ?? source.name,
                    style: const TextStyle(color: AppTheme.lightTextPrimary),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(androidAudioConfigProvider.notifier).updateAudioSource(value);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Audio manager mode dropdown
            const Text(
              'オーディオマネージャーモード',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '音声処理モードを選択します（エコーキャンセルに影響）',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AudioManagerMode>(
              value: config.audioManagerMode,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppTheme.lightSurfaceColor,
              items: AudioManagerMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(
                    AndroidAudioConfig.audioModeDisplayNames[mode] ?? mode.name,
                    style: const TextStyle(color: AppTheme.lightTextPrimary),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(androidAudioConfigProvider.notifier).updateAudioManagerMode(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '重要な注意事項',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voice Communication + In Communication 以外の設定ではエコーが発生し、AIが自分の声に誤って反応する可能性があります。',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.lightTextSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '推奨: Voice Communication + In Communication',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
