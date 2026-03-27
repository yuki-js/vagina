import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

/// Widget displayed when no text agents exist
class EmptyAgentsView extends StatelessWidget {
  final VoidCallback onCreateAgent;

  const EmptyAgentsView({
    super.key,
    required this.onCreateAgent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'テキストエージェントがありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'テキストエージェントを作成して\n高度なAI機能を利用できます',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onCreateAgent,
            icon: const Icon(Icons.add),
            label: const Text('最初のエージェントを作成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
