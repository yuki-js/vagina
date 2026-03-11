import 'package:flutter/material.dart';
import 'package:vagina/feat/call/widgets/open_files_action_bar.dart';
import 'package:vagina/models/open_file_tab.dart';
import 'package:vagina/core/theme/app_theme.dart';

/// Open-files header with navigation to call and action menu.
class OpenFilesHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final OpenFileTab? selectedTab;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final String editedContent;
  final bool hideBackButton;

  const OpenFilesHeader({
    super.key,
    required this.onBackPressed,
    required this.selectedTab,
    required this.isEditing,
    required this.onEditToggle,
    required this.editedContent,
    this.hideBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          if (!hideBackButton)
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
                'ファイル',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          if (selectedTab != null)
            OpenFilesMoreMenu(
              content: isEditing ? editedContent : selectedTab!.content,
              isEditing: isEditing,
              onEditToggle: onEditToggle,
              showEditButton: selectedTab!.mimeType != 'text/html',
              canUndo: false,
              canRedo: false,
              onUndo: () {},
              onRedo: () {},
            )
          else
            const SizedBox(width: 48), // Balance for the back button
        ],
      ),
    );
  }
}
