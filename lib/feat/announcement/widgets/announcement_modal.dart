import 'package:flutter/material.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';

class AnnouncementModal extends StatelessWidget {
  final ModalAnnouncementTopic topic;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const AnnouncementModal({
    super.key,
    required this.topic,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Semantics(
        label: topic.image.altText,
        image: true,
        button: onTap != null,
        child: ExcludeSemantics(
          child: Image.network(
            topic.image.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(32),
                child: Icon(
                  Icons.campaign,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
        ),
      ),
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: onTap == null
                    ? image
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('announcement_modal_primary_surface'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: onTap,
                          child: Stack(
                            children: [
                              image,
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.open_in_new,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (onDismissed != null)
            Positioned(
              top: 8,
              right: 8,
              child: ClipOval(
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.96),
                  child: IconButton(
                    key: const Key('announcement_modal_close_button'),
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
    );
  }
}
