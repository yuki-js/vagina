import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

/// Tools tab - shows available tools and allows enabling/disabling them
class ToolsTab extends ConsumerWidget {
  const ToolsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire up with tool service
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'ツール',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '利用可能なツールの管理',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Placeholder for tools
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build,
                size: 64,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'ツール管理機能は準備中です',
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
