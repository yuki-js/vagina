import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/speed_dial.dart';
import '../../utils/call_navigation_utils.dart';
import '../speed_dial/speed_dial_config_screen.dart';

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
                final crossAxisCount =
                    (constraints.maxWidth / cardWidth).floor().clamp(2, 6);

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
    final isDefault = speedDial.isDefault;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _startCall(context, ref, speedDial),
        onLongPress: () => _editSpeedDial(context, speedDial),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Emoji - Headset for default, emoji for custom
              if (isDefault)
                const Icon(
                  Icons.headset_mic,
                  size: 48,
                  color: AppTheme.primaryColor,
                )
              else
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
    await CallNavigationUtils.navigateToCallWithSpeedDial(
      context: context,
      ref: ref,
      speedDial: speedDial,
    );
  }

  Future<void> _editSpeedDial(
    BuildContext context,
    SpeedDial speedDial,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeedDialConfigScreen(
          speedDialId: speedDial.id,
          speedDial: speedDial,
        ),
      ),
    );
  }
}
