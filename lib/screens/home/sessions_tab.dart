import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

/// Sessions tab - shows call history
class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire up with sessions provider
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'セッション履歴',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '過去の通話履歴を確認',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Placeholder for sessions
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '通話履歴がまだありません',
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
