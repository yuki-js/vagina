import 'package:flutter/material.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';

class AnnouncementMarquee extends StatelessWidget {
  final MarqueeAnnouncementTopic topic;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const AnnouncementMarquee({
    super.key,
    required this.topic,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.08);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.textContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: backgroundColor,
      child: Row(
        children: [
          if (onDismissed != null)
            IconButton(
              key: const Key('announcement_marquee_close_button'),
              onPressed: onDismissed,
              icon: const Icon(Icons.close),
            ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}
