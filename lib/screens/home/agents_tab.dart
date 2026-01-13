import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

/// Agents tab - currently under construction
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              '工事中',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'このページは現在工事中です',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
