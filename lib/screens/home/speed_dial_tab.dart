import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/speed_dial.dart';
import '../call/call_screen.dart';

/// Speed dial tab - shows saved character presets for quick call start
class SpeedDialTab extends ConsumerWidget {
  const SpeedDialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedDialsAsync = ref.watch(refreshableSpeedDialsProvider);

    return speedDialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラー: $error'),
      ),
      data: (speedDials) {
        if (speedDials.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'スピードダイヤル',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'お気に入りのキャラクターに素早く発信',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Speed dial grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: speedDials.length,
              itemBuilder: (context, index) {
                final speedDial = speedDials[index];
                return _buildSpeedDialCard(context, ref, speedDial);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'スピードダイヤル',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'お気に入りのキャラクターに素早く発信',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_border,
                size: 64,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'スピードダイヤルがまだありません',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '右上の + ボタンで追加できます',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialCard(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _startCall(context, ref, speedDial),
        onLongPress: () => _editSpeedDial(context, ref, speedDial),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Emoji
              Text(
                speedDial.iconEmoji ?? '⭐',
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                speedDial.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Voice
              Text(
                speedDial.voice,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) async {
    // Update assistant config with speed dial settings
    ref.read(assistantConfigProvider.notifier).updateName(speedDial.name);
    ref.read(assistantConfigProvider.notifier).updateInstructions(speedDial.systemPrompt);
    ref.read(assistantConfigProvider.notifier).updateVoice(speedDial.voice);

    // Navigate to call screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(speedDialId: speedDial.id),
      ),
    );
  }

  Future<void> _editSpeedDial(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(speedDial.name),
        content: const Text('このスピードダイヤルを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteSpeedDial(speedDial.id);
      
      // Refresh the list
      ref.invalidate(refreshableSpeedDialsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
      }
    }
  }
}
