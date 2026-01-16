import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Chat header with navigation to call
class ChatHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const ChatHeader({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!hideBackButton)
            const SizedBox(width: 80), // Balance for the navigation button
          Expanded(
            child: Center(
              child: Text(
                'チャット',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          if (!hideBackButton)
            GestureDetector(
              onTap: onBackPressed,
              child: Row(
                children: [
                  Text(
                    '通話画面',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
