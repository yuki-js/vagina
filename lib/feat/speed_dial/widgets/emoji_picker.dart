import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Simple emoji picker widget
class EmojiPicker extends StatelessWidget {
  final String? selectedEmoji;
  final ValueChanged<String> onEmojiSelected;

  const EmojiPicker({
    super.key,
    this.selectedEmoji,
    required this.onEmojiSelected,
  });

  // Common emojis for speed dial icons
  static const List<String> emojis = [
    '⭐',
    '❤️',
    '😊',
    '👍',
    '🎵',
    '🎨',
    '📱',
    '💼',
    '🏠',
    '🚀',
    '🎓',
    '⚡',
    '🌟',
    '🔥',
    '💡',
    '🎯',
    '🎭',
    '🎪',
    '🎬',
    '🎮',
    '🎲',
    '🎸',
    '🎹',
    '🎺',
    '👤',
    '👥',
    '👨',
    '👩',
    '👶',
    '🧑',
    '👴',
    '👵',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🌸',
    '🌺',
    '🌻',
    '🌷',
    '🌹',
    '🏵️',
    '🌴',
    '🌵',
    '🍎',
    '🍊',
    '🍋',
    '🍌',
    '🍉',
    '🍇',
    '🍓',
    '🍑',
    '⚽',
    '🏀',
    '🏈',
    '⚾',
    '🎾',
    '🏐',
    '🏉',
    '🎱',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate responsive column count (more columns on wider screens)
    final crossAxisCount = (screenWidth / 60).floor().clamp(4, 8);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        minHeight: 400,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.lightTextSecondary.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_emotions, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  l10n.speedDialEmojiPickerTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                if (selectedEmoji != null)
                  Text(
                    selectedEmoji!,
                    style: const TextStyle(fontSize: 32),
                  ),
              ],
            ),
          ),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                final isSelected = emoji == selectedEmoji;

                return InkWell(
                  onTap: () => onEmojiSelected(emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
