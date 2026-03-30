import 'package:flutter/material.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';

class AnnouncementBanner extends StatelessWidget {
  final BannerAnnouncementTopic topic;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const AnnouncementBanner({
    super.key,
    required this.topic,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;

    return AspectRatio(
      aspectRatio: 5,
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: topic.image.altText,
                image: true,
                button: onTap != null,
                child: ExcludeSemantics(
                  child: Image.network(
                    topic.image.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.campaign,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('announcement_banner_primary_surface'),
                    onTap: onTap,
                  ),
                ),
              ),
            if (onDismissed != null)
              Positioned(
                top: 8,
                right: 8,
                child: ClipOval(
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.92),
                    child: IconButton(
                      key: const Key('announcement_banner_close_button'),
                      onPressed: onDismissed,
                      icon: const Icon(Icons.close),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
