import 'package:flutter/material.dart';

import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/core/theme/app_theme.dart';

/// Individual notepad tab item.
class NotepadTabItem extends StatelessWidget {
  final NotepadTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const NotepadTabItem({
    super.key,
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getMimeTypeIcon(tab.mimeType),
              size: 16,
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                tab.title,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMimeTypeIcon(String mimeType) {
    switch (mimeType) {
      case 'text/markdown':
        return Icons.article;
      case 'text/html':
        return Icons.code;
      case 'text/plain':
      default:
        return Icons.description;
    }
  }
}
