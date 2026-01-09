import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/assistant_config.dart';

/// Agents tab - shows current assistant configuration
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantConfig = ref.watch(assistantConfigProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'エージェント設定',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'アシスタントの動作設定',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Current configuration display
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        assistantConfig.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '音声',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assistantConfig.voice,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'システムプロンプト',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assistantConfig.instructions.isEmpty
                      ? '（デフォルト）'
                      : assistantConfig.instructions,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.lightTextPrimary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Voice selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '音声選択',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTextSecondary,
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
                      style: const TextStyle(color: AppTheme.lightTextPrimary),
                    ),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Info text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'スピードダイヤルから通話を開始すると、一時的にその設定が適用されます',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
