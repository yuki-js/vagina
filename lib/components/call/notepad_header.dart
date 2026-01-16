import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/notepad_tab.dart';
import '../../providers/providers.dart';
import '../notepad_action_bar.dart';

/// Notepad header with navigation to call and more menu
class NotepadHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final NotepadTab? selectedTab;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final String editedContent;
  final bool hideBackButton;

  const NotepadHeader({
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
                'ノートパッド',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          if (selectedTab != null)
            Consumer(
              builder: (context, ref, child) {
                return NotepadMoreMenu(
                  content: isEditing ? editedContent : selectedTab!.content,
                  isEditing: isEditing,
                  onEditToggle: onEditToggle,
                  showEditButton: selectedTab!.mimeType != 'text/html',
                  canUndo: selectedTab!.canUndo,
                  canRedo: selectedTab!.canRedo,
                  onUndo: () {
                    final service = ref.read(notepadServiceProvider);
                    service.undo(selectedTab!.id);
                  },
                  onRedo: () {
                    final service = ref.read(notepadServiceProvider);
                    service.redo(selectedTab!.id);
                  },
                );
              },
            )
          else
            const SizedBox(width: 48), // Balance for the back button
        ],
      ),
    );
  }
}
