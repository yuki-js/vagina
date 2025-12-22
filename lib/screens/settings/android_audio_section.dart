import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
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
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'マイク入力に使用するオーディオソースを選択します',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AndroidAudioSource>(
              value: config.audioSource,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppTheme.surfaceColor,
              items: AndroidAudioSource.values.map((source) {
                return DropdownMenuItem(
                  value: source,
                  child: Text(
                    AndroidAudioConfig.audioSourceDisplayNames[source] ?? source.name,
                    style: const TextStyle(color: AppTheme.textPrimary),
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
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '音声処理モードを選択します（エコーキャンセルに影響）',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AudioManagerMode>(
              value: config.audioManagerMode,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppTheme.surfaceColor,
              items: AudioManagerMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(
                    AndroidAudioConfig.audioModeDisplayNames[mode] ?? mode.name,
                    style: const TextStyle(color: AppTheme.textPrimary),
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
            Text(
              '推奨: Voice Communication + In Communication モードでエコーキャンセル効果が最大化されます',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
