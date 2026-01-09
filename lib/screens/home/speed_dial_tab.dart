import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

/// Speed dial tab - shows saved character presets for quick call start
class SpeedDialTab extends ConsumerWidget {
  const SpeedDialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire up with speed dial provider
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
        // Placeholder for speed dials
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
            ],
          ),
        ),
      ],
    );
  }
}
