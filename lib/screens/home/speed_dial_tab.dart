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
            // Speed dial grid with fixed-size cards
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate number of columns based on screen width
                // Each card should be approximately 160px wide
                final cardWidth = 160.0;
                final crossAxisCount = (constraints.maxWidth / cardWidth).floor().clamp(2, 6);
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: speedDials.length,
                  itemBuilder: (context, index) {
                    final speedDial = speedDials[index];
                    return _buildSpeedDialCard(context, ref, speedDial);
                  },
                );
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
    // Save current assistant config to restore after call
    final originalConfig = ref.read(assistantConfigProvider);
    
    // Temporarily update assistant config with speed dial settings
    ref.read(assistantConfigProvider.notifier).updateName(speedDial.name);
    ref.read(assistantConfigProvider.notifier).updateInstructions(speedDial.systemPrompt);
    ref.read(assistantConfigProvider.notifier).updateVoice(speedDial.voice);

    // Set speed dial ID for session tracking
    final callService = ref.read(callServiceProvider);
    callService.setSpeedDialId(speedDial.id);

    // Navigate to call screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CallScreen(),
      ),
    );
    
    // Restore original config after call ends
    ref.read(assistantConfigProvider.notifier).updateName(originalConfig.name);
    ref.read(assistantConfigProvider.notifier).updateInstructions(originalConfig.instructions);
    ref.read(assistantConfigProvider.notifier).updateVoice(originalConfig.voice);
    
    // Clear speed dial ID after call
    callService.setSpeedDialId(null);
  }

  Future<void> _editSpeedDial(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(speedDial.name),
        content: const Text('操作を選択してください'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('edit'),
            child: const Text('編集'),
          ),
        ],
      ),
    );

    if (result == 'delete' && context.mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteSpeedDial(speedDial.id);
      
      // Refresh the list
      ref.invalidate(refreshableSpeedDialsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
      }
    } else if (result == 'edit' && context.mounted) {
      await _showEditDialog(context, ref, speedDial);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) async {
    final formKey = GlobalKey<FormState>();
    String name = speedDial.name;
    String systemPrompt = speedDial.systemPrompt;
    String voice = speedDial.voice;
    String iconEmoji = speedDial.iconEmoji ?? '⭐';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スピードダイヤルを編集'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    labelText: '名前',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '名前を入力してください';
                    }
                    return null;
                  },
                  onSaved: (value) => name = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: systemPrompt,
                  decoration: const InputDecoration(
                    labelText: 'システムプロンプト',
                    hintText: 'アシスタントの振る舞いを設定',
                  ),
                  maxLines: 3,
                  onSaved: (value) => systemPrompt = value ?? '',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: voice,
                  decoration: const InputDecoration(
                    labelText: '音声',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                    DropdownMenuItem(value: 'echo', child: Text('Echo')),
                    DropdownMenuItem(value: 'shimmer', child: Text('Shimmer')),
                  ],
                  onChanged: (value) {
                    if (value != null) voice = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: iconEmoji,
                  decoration: const InputDecoration(
                    labelText: 'アイコン絵文字',
                    hintText: '例: ⭐',
                  ),
                  maxLength: 2,
                  onSaved: (value) => iconEmoji = value ?? '⭐',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final storage = ref.read(storageServiceProvider);
      final updatedSpeedDial = SpeedDial(
        id: speedDial.id,
        name: name,
        systemPrompt: systemPrompt,
        voice: voice,
        iconEmoji: iconEmoji,
        createdAt: speedDial.createdAt,
      );
      
      await storage.updateSpeedDial(updatedSpeedDial);
      
      // Refresh the list
      ref.invalidate(refreshableSpeedDialsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新しました')),
        );
      }
    }
  }
}
