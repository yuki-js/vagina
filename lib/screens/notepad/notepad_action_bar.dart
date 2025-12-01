import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

/// Popup menu with copy, share, and edit options for notepad content
class NotepadMoreMenu extends StatelessWidget {
  final String content;
  final bool isEditing;
  final VoidCallback? onEditToggle;
  final bool showEditButton;

  const NotepadMoreMenu({
    super.key,
    required this.content,
    this.isEditing = false,
    this.onEditToggle,
    this.showEditButton = true,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コピーしました'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareContent(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(text: content));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('共有に失敗しました'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_horiz,
        color: AppTheme.textSecondary,
      ),
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      offset: const Offset(0, 40),
      onSelected: (value) {
        switch (value) {
          case 'copy':
            _copyToClipboard(context);
            break;
          case 'share':
            _shareContent(context);
            break;
          case 'edit':
            onEditToggle?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              const Text('コピー', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_rounded, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              const Text('共有', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        ),
        if (showEditButton && onEditToggle != null)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  size: 20,
                  color: isEditing ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? '完了' : '編集',
                  style: TextStyle(
                    color: isEditing ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
