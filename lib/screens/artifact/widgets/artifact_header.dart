import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Header for artifact page
class ArtifactHeader extends StatelessWidget {
  final VoidCallback onBackPressed;

  const ArtifactHeader({
    super.key,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackPressed,
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                Text(
                  '通話画面',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'アーティファクト',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 80), // Balance for the back button
        ],
      ),
    );
  }
}
