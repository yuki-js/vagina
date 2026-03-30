import 'package:flutter/material.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';

typedef AnnouncementDialogButtonHandler = Future<void> Function(
  AnnouncementButton button,
);
typedef AnnouncementDialogDismissHandler = Future<void> Function();

class AnnouncementDialog extends StatelessWidget {
  final DialogAnnouncementTopic topic;
  final AnnouncementDialogButtonHandler onButtonPressed;
  final AnnouncementDialogDismissHandler? onDismissed;

  const AnnouncementDialog({
    super.key,
    required this.topic,
    required this.onButtonPressed,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              topic.title,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (onDismissed != null)
            IconButton(
              key: const Key('announcement_dialog_close_button'),
              onPressed: onDismissed,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topic.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    topic.image!.imageUrl,
                    fit: BoxFit.cover,
                    semanticLabel: topic.image!.altText,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                topic.message,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      actions: topic.buttons.map((button) {
        return _buildButton(context, button);
      }).toList(),
    );
  }

  Widget _buildButton(BuildContext context, AnnouncementButton button) {
    final theme = Theme.of(context);
    Future<void> onPressed() {
      return onButtonPressed(button);
    }

    if (button.isPrimary) {
      final style = button.isNegative
          ? FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            )
          : null;

      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(button.label),
      );
    }

    final style = button.isNegative
        ? TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          )
        : null;

    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Text(button.label),
    );
  }
}
