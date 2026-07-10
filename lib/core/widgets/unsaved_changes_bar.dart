import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UnsavedChangesBar extends StatefulWidget {
  final ValueListenable<int> emphasisRevision;
  final String message;
  final String discardLabel;
  final String compactDiscardLabel;
  final String saveLabel;
  final String savingLabel;
  final bool isSaving;
  final VoidCallback? onDiscard;
  final VoidCallback? onSave;

  const UnsavedChangesBar({
    super.key,
    required this.emphasisRevision,
    required this.message,
    required this.discardLabel,
    required this.compactDiscardLabel,
    required this.saveLabel,
    required this.savingLabel,
    required this.isSaving,
    required this.onDiscard,
    required this.onSave,
  });

  @override
  State<UnsavedChangesBar> createState() => _UnsavedChangesBarState();
}

class _UnsavedChangesBarState extends State<UnsavedChangesBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flashAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    widget.emphasisRevision.addListener(_onEmphasisRevision);
  }

  @override
  void didUpdateWidget(covariant UnsavedChangesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emphasisRevision != widget.emphasisRevision) {
      oldWidget.emphasisRevision.removeListener(_onEmphasisRevision);
      widget.emphasisRevision.addListener(_onEmphasisRevision);
    }
  }

  @override
  void dispose() {
    widget.emphasisRevision.removeListener(_onEmphasisRevision);
    _animationController.dispose();
    super.dispose();
  }

  void _onEmphasisRevision() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animationController.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _animationController.value = 0;
      });
      return;
    }
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        final emphasis = _flashAnimation.value;
        return Transform.scale(
          scale: 1 + emphasis * 0.025,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: 0.12 + emphasis * 0.42,
                  ),
                  blurRadius: 18 + emphasis * 14,
                  spreadRadius: emphasis * 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        elevation: 6,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final message = Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: widget.onDiscard,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                    ),
                    child: Text(
                      compact
                          ? widget.compactDiscardLabel
                          : widget.discardLabel,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: widget.onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: widget.isSaving
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(widget.savingLabel),
                            ],
                          )
                        : Text(widget.saveLabel),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    message,
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
