import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/theme/app_theme.dart';
import 'package:vagina/providers/providers.dart';
import 'package:vagina/models/assistant_config.dart';
import 'settings_card.dart';

/// Voice settings section widget
class VoiceSettingsSection extends ConsumerWidget {
  const VoiceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantConfig = ref.watch(assistantConfigProvider);
    final noiseReduction = ref.watch(noiseReductionProvider);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'アシスタント音声',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...AssistantConfig.availableVoices.map(
            (voice) => RadioGroup<String>(
              groupValue: assistantConfig.voice,
              onChanged: (value) {
                if (value != null) {
                  ref.read(assistantConfigProvider.notifier).updateVoice(value);
                }
              },
              child: RadioListTile<String>(
                value: voice,
                title: Text(
                  voice[0].toUpperCase() + voice.substring(1),
                  style: const TextStyle(color: AppTheme.lightTextPrimary),
                ),
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ノイズ軽減',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: noiseReduction,
            onChanged: (value) {
              if (value != null && value != noiseReduction) {
                _handleNoiseReductionChange(ref, value);
              }
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'near',
                  title: const Text(
                    '近距離',
                    style: TextStyle(color: AppTheme.lightTextPrimary),
                  ),
                  subtitle: Text(
                    '近くで話すときに適しています',
                    style: TextStyle(
                      color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  activeColor: AppTheme.primaryColor,
                ),
                RadioListTile<String>(
                  value: 'far',
                  title: const Text(
                    '遠距離',
                    style: TextStyle(color: AppTheme.lightTextPrimary),
                  ),
                  subtitle: Text(
                    '遠くから話すときに適しています',
                    style: TextStyle(
                      color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleNoiseReductionChange(WidgetRef ref, String value) {
    // Update the provider state
    ref.read(noiseReductionProvider.notifier).set(value);
    
    // Update the API client
    final apiClient = ref.read(realtimeApiClientProvider);
    apiClient.setNoiseReduction(value);
    
    // If connected, update session config
    final isCallActive = ref.read(isCallActiveProvider);
    if (isCallActive) {
      apiClient.updateSessionConfig();
    }
  }
}
