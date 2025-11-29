import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Edit/Done toggle button for notepad content
class NotepadEditButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onTap;

  const NotepadEditButton({
    super.key,
    required this.isEditing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.check : Icons.edit,
              size: 14,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              isEditing ? '完了' : '編集',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
