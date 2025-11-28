import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/assistant_config.dart';
import '../../components/settings_card.dart';

/// Voice settings section widget
class VoiceSettingsSection extends ConsumerWidget {
  const VoiceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantConfig = ref.watch(assistantConfigProvider);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'アシスタント音声',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...AssistantConfig.availableVoices.map(
            (voice) => RadioListTile<String>(
              value: voice,
              groupValue: assistantConfig.voice,
              onChanged: (value) {
                if (value != null) {
                  ref.read(assistantConfigProvider.notifier).updateVoice(value);
                }
              },
              title: Text(
                voice[0].toUpperCase() + voice.substring(1),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              activeColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
