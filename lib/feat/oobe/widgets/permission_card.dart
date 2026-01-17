import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

/// Permission item configuration
class PermissionItem {
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;
  bool isGranted;

  PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.isRequired,
    required this.isGranted,
  });
}

/// Permission card widget for displaying individual permission requests
class PermissionCard extends StatelessWidget {
  final PermissionItem permission;
  final VoidCallback onRequest;

  const PermissionCard({
    super.key,
    required this.permission,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: permission.isGranted
              ? AppTheme.successColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: permission.isGranted
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
            child: Icon(
              permission.isGranted ? Icons.check : permission.icon,
              color: permission.isGranted
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      permission.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (permission.isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '必須',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  permission.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action button
          if (!permission.isGranted)
            OutlinedButton(
              onPressed: onRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '許可',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
