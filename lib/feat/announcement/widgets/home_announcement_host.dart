import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/announcement/widgets/announcement_banner.dart';
import 'package:vagina/feat/announcement/widgets/announcement_dialog.dart';
import 'package:vagina/feat/announcement/widgets/announcement_marquee.dart';
import 'package:vagina/feat/announcement/widgets/announcement_modal.dart';

typedef AnnouncementLinkOpener = Future<bool> Function(Uri uri);

@visibleForTesting
const Duration kAnnouncementMarqueeRotationInterval = Duration(seconds: 6);

@visibleForTesting
const Duration kAnnouncementMarqueeSwitchDuration = Duration(milliseconds: 250);

@visibleForTesting
class HomeAnnouncementSelection {
  final List<BannerAnnouncementTopic> bannerTopics;
  final List<ModalAnnouncementTopic> modalTopics;
  final List<DialogAnnouncementTopic> dialogTopics;
  final List<MarqueeAnnouncementTopic> marqueeTopics;

  const HomeAnnouncementSelection({
    this.bannerTopics = const <BannerAnnouncementTopic>[],
    this.modalTopics = const <ModalAnnouncementTopic>[],
    this.dialogTopics = const <DialogAnnouncementTopic>[],
    this.marqueeTopics = const <MarqueeAnnouncementTopic>[],
  });

  BannerAnnouncementTopic? get bannerTopic =>
      bannerTopics.isEmpty ? null : bannerTopics.first;

  ModalAnnouncementTopic? get modalTopic =>
      modalTopics.isEmpty ? null : modalTopics.first;

  DialogAnnouncementTopic? get dialogTopic =>
      dialogTopics.isEmpty ? null : dialogTopics.first;

  MarqueeAnnouncementTopic? get marqueeTopic =>
      marqueeTopics.isEmpty ? null : marqueeTopics.first;
}

@visibleForTesting
HomeAnnouncementSelection selectHomeAnnouncements(
  Iterable<AnnouncementTopic> topics, {
  Set<String> hiddenBannerTopicIds = const <String>{},
  Set<String> hiddenModalTopicIds = const <String>{},
  Set<String> hiddenDialogTopicIds = const <String>{},
  Set<String> hiddenMarqueeTopicIds = const <String>{},
}) {
  final displayableTopics = topics
      .where(
        (topic) =>
            topic is BannerAnnouncementTopic ||
            topic is ModalAnnouncementTopic ||
            topic is DialogAnnouncementTopic ||
            topic is MarqueeAnnouncementTopic,
      )
      .toList()
    ..sort(_compareAnnouncementTopics);

  final bannerTopics = <BannerAnnouncementTopic>[];
  final modalTopics = <ModalAnnouncementTopic>[];
  final dialogTopics = <DialogAnnouncementTopic>[];
  final marqueeTopics = <MarqueeAnnouncementTopic>[];

  for (final topic in displayableTopics) {
    if (topic is BannerAnnouncementTopic &&
        !hiddenBannerTopicIds.contains(topic.id)) {
      bannerTopics.add(topic);
    }

    if (topic is ModalAnnouncementTopic &&
        !hiddenModalTopicIds.contains(topic.id)) {
      modalTopics.add(topic);
    }

    if (topic is DialogAnnouncementTopic &&
        !hiddenDialogTopicIds.contains(topic.id)) {
      dialogTopics.add(topic);
    }

    if (topic is MarqueeAnnouncementTopic &&
        !hiddenMarqueeTopicIds.contains(topic.id)) {
      marqueeTopics.add(topic);
    }
  }

  return HomeAnnouncementSelection(
    bannerTopics: bannerTopics,
    modalTopics: modalTopics,
    dialogTopics: dialogTopics,
    marqueeTopics: marqueeTopics,
  );
}

class HomeAnnouncementHost extends StatefulWidget {
  final AnnouncementService service;
  final AnnouncementLinkOpener? linkOpener;

  const HomeAnnouncementHost({
    super.key,
    required this.service,
    this.linkOpener,
  });

  @override
  State<HomeAnnouncementHost> createState() => _HomeAnnouncementHostState();
}

class _HomeAnnouncementHostState extends State<HomeAnnouncementHost> {
  static final Logger _logger = Logger('HomeAnnouncementHost');

  final Set<String> _dismissedTopicIds = <String>{};
  final Set<String> _hiddenBannerTopicIds = <String>{};
  final Set<String> _hiddenModalTopicIds = <String>{};
  final Set<String> _hiddenDialogTopicIds = <String>{};
  final Set<String> _hiddenMarqueeTopicIds = <String>{};

  List<AnnouncementTopic> _allTopics = const <AnnouncementTopic>[];
  List<BannerAnnouncementTopic> _bannerTopics =
      const <BannerAnnouncementTopic>[];
  List<ModalAnnouncementTopic> _modalTopics = const <ModalAnnouncementTopic>[];
  List<DialogAnnouncementTopic> _dialogTopics =
      const <DialogAnnouncementTopic>[];
  List<MarqueeAnnouncementTopic> _marqueeTopics =
      const <MarqueeAnnouncementTopic>[];
  int _marqueeIndex = 0;
  bool _isDialogVisible = false;
  bool _isModalVisible = false;
  bool _isOverlayScheduled = false;
  Timer? _marqueeRotationTimer;

  AnnouncementLinkOpener get _linkOpener =>
      widget.linkOpener ?? _defaultAnnouncementLinkOpener;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAnnouncements());
  }

  @override
  void didUpdateWidget(covariant HomeAnnouncementHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _marqueeRotationTimer?.cancel();
      _dismissedTopicIds.clear();
      _hiddenBannerTopicIds.clear();
      _hiddenModalTopicIds.clear();
      _hiddenDialogTopicIds.clear();
      _hiddenMarqueeTopicIds.clear();
      _allTopics = const <AnnouncementTopic>[];
      _bannerTopics = const <BannerAnnouncementTopic>[];
      _modalTopics = const <ModalAnnouncementTopic>[];
      _dialogTopics = const <DialogAnnouncementTopic>[];
      _marqueeTopics = const <MarqueeAnnouncementTopic>[];
      _marqueeIndex = 0;
      _isDialogVisible = false;
      _isModalVisible = false;
      _isOverlayScheduled = false;
      unawaited(_loadAnnouncements());
    }
  }

  @override
  void dispose() {
    _marqueeRotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final topicList = await widget.service.fetchTopicList();
      final dismissedTopicIds = await widget.service.getDismissedTopicIds();
      if (!mounted) {
        return;
      }

      _dismissedTopicIds
        ..clear()
        ..addAll(dismissedTopicIds);
      _hiddenBannerTopicIds.clear();
      _hiddenModalTopicIds.clear();
      _hiddenDialogTopicIds.clear();
      _hiddenMarqueeTopicIds.clear();
      _allTopics = topicList.topics;

      _recomputeSelection();
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to load announcements for home host.',
        error,
        stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _allTopics = const <AnnouncementTopic>[];
        _bannerTopics = const <BannerAnnouncementTopic>[];
        _modalTopics = const <ModalAnnouncementTopic>[];
        _dialogTopics = const <DialogAnnouncementTopic>[];
        _marqueeTopics = const <MarqueeAnnouncementTopic>[];
        _marqueeIndex = 0;
      });
      _configureMarqueeRotation();
    }
  }

  List<AnnouncementTopic> get _visibleTopics {
    return widget.service.filterVisibleTopics(
      _allTopics,
      dismissedTopicIds: _dismissedTopicIds,
    );
  }

  void _recomputeSelection({bool scheduleOverlayPresentation = true}) {
    if (!mounted) {
      return;
    }

    final currentMarqueeId = _currentMarqueeTopic?.id;
    final previousMarqueeIndex = _marqueeIndex;
    final selection = selectHomeAnnouncements(
      _visibleTopics,
      hiddenBannerTopicIds: _hiddenBannerTopicIds,
      hiddenModalTopicIds: _hiddenModalTopicIds,
      hiddenDialogTopicIds: _hiddenDialogTopicIds,
      hiddenMarqueeTopicIds: _hiddenMarqueeTopicIds,
    );
    final resolvedMarqueeIndex = _resolveMarqueeIndex(
      topics: selection.marqueeTopics,
      currentTopicId: currentMarqueeId,
      previousIndex: previousMarqueeIndex,
    );

    setState(() {
      _bannerTopics = selection.bannerTopics;
      _modalTopics = selection.modalTopics;
      _dialogTopics = selection.dialogTopics;
      _marqueeTopics = selection.marqueeTopics;
      _marqueeIndex = resolvedMarqueeIndex;
    });

    _configureMarqueeRotation();
    if (scheduleOverlayPresentation) {
      _scheduleOverlayPresentation();
    }
  }

  int _resolveMarqueeIndex({
    required List<MarqueeAnnouncementTopic> topics,
    required String? currentTopicId,
    required int previousIndex,
  }) {
    if (topics.isEmpty) {
      return 0;
    }

    if (currentTopicId != null) {
      final currentIndex =
          topics.indexWhere((topic) => topic.id == currentTopicId);
      if (currentIndex != -1) {
        return currentIndex;
      }
    }

    if (previousIndex >= 0 && previousIndex < topics.length) {
      return previousIndex;
    }

    return 0;
  }

  void _configureMarqueeRotation() {
    _marqueeRotationTimer?.cancel();
    _marqueeRotationTimer = null;

    if (_marqueeTopics.length < 2) {
      return;
    }

    _marqueeRotationTimer = Timer.periodic(
      kAnnouncementMarqueeRotationInterval,
      (_) {
        if (!mounted || _marqueeTopics.length < 2) {
          return;
        }

        setState(() {
          _marqueeIndex = (_marqueeIndex + 1) % _marqueeTopics.length;
        });
      },
    );
  }

  MarqueeAnnouncementTopic? get _currentMarqueeTopic {
    if (_marqueeTopics.isEmpty) {
      return null;
    }

    final index = _marqueeIndex >= 0 && _marqueeIndex < _marqueeTopics.length
        ? _marqueeIndex
        : 0;
    return _marqueeTopics[index];
  }

  void _scheduleOverlayPresentation() {
    final topic = _selectPendingOverlayTopic();
    if (topic == null || _isOverlayVisible || _isOverlayScheduled) {
      return;
    }

    _isOverlayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isOverlayScheduled = false;
      if (!mounted) {
        return;
      }

      final pendingTopic = _selectPendingOverlayTopic();
      if (pendingTopic == null || _isOverlayVisible) {
        return;
      }

      switch (pendingTopic) {
        case ModalAnnouncementTopic():
          unawaited(_presentModal(pendingTopic));
          break;
        case DialogAnnouncementTopic():
          unawaited(_presentDialog(pendingTopic));
          break;
        default:
          break;
      }
    });
  }

  bool get _isOverlayVisible => _isDialogVisible || _isModalVisible;

  AnnouncementTopic? _selectPendingOverlayTopic() {
    final candidates = <AnnouncementTopic>[
      if (_modalTopics.isNotEmpty) _modalTopics.first,
      if (_dialogTopics.isNotEmpty) _dialogTopics.first,
    ];

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort(_compareAnnouncementTopics);
    return candidates.first;
  }

  Future<void> _presentDialog(DialogAnnouncementTopic topic) async {
    if (!mounted || _isDialogVisible) {
      return;
    }

    _isDialogVisible = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AnnouncementDialog(
              topic: topic,
              onButtonPressed: (button) async {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _handleTopicAction(
                  button.action,
                  topic: topic,
                  removeFromSessionOnOpenLink: true,
                );
              },
              onDismissed: topic.dismissingAction == null
                  ? null
                  : () async {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      await _handleTopicAction(
                        topic.dismissingAction!,
                        topic: topic,
                      );
                    },
            ),
          );
        },
      );
    } finally {
      _isDialogVisible = false;
      _recomputeSelection();
    }
  }

  Future<void> _presentModal(ModalAnnouncementTopic topic) async {
    if (!mounted || _isModalVisible) {
      return;
    }

    _isModalVisible = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AnnouncementModal(
              topic: topic,
              onTap: topic.action == null
                  ? null
                  : () async {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      await _handleTopicAction(
                        topic.action!,
                        topic: topic,
                        removeFromSessionOnOpenLink: true,
                      );
                    },
              onDismissed: topic.dismissingAction == null
                  ? null
                  : () async {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      await _handleTopicAction(
                        topic.dismissingAction!,
                        topic: topic,
                      );
                    },
            ),
          );
        },
      );
    } finally {
      _isModalVisible = false;
      _recomputeSelection();
    }
  }

  Future<void> _handleTopicAction(
    AnnouncementAction action, {
    required AnnouncementTopic topic,
    bool removeFromSessionOnOpenLink = false,
  }) async {
    switch (action) {
      case OpenLinkAnnouncementAction(:final linkUrl):
        if (removeFromSessionOnOpenLink) {
          _markTopicHiddenForSession(topic);
          _recomputeSelection();
        }

        final uri = Uri.tryParse(linkUrl);
        if (uri == null) {
          _logger.warning('Invalid announcement link URL: $linkUrl');
          return;
        }

        final didLaunch = await _linkOpener(uri);
        if (!didLaunch) {
          _logger.warning('Unable to launch announcement link: $uri');
        }

      case DismissTopicAnnouncementAction(:final showAgain):
        _markTopicHiddenForSession(topic);
        if (!showAgain) {
          _dismissedTopicIds.add(topic.id);
        }
        _recomputeSelection();

        if (showAgain) {
          return;
        }

        try {
          await widget.service.dismissTopic(topic.id);
        } catch (error, stackTrace) {
          _logger.warning(
            'Failed to persist dismissed announcement topic: ${topic.id}',
            error,
            stackTrace,
          );
        }
    }
  }

  void _markTopicHiddenForSession(AnnouncementTopic topic) {
    if (topic is BannerAnnouncementTopic) {
      _hiddenBannerTopicIds.add(topic.id);
      return;
    }

    if (topic is ModalAnnouncementTopic) {
      _hiddenModalTopicIds.add(topic.id);
      return;
    }

    if (topic is DialogAnnouncementTopic) {
      _hiddenDialogTopicIds.add(topic.id);
      return;
    }

    if (topic is MarqueeAnnouncementTopic) {
      _hiddenMarqueeTopicIds.add(topic.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerTopics = _bannerTopics;
    final marqueeTopic = _currentMarqueeTopic;

    if (bannerTopics.isEmpty && marqueeTopic == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marqueeTopic != null)
          AnimatedSwitcher(
            duration: kAnnouncementMarqueeSwitchDuration,
            transitionBuilder: (child, animation) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
                reverseCurve: Curves.easeIn,
              );

              return FadeTransition(
                opacity: curvedAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
            child: AnnouncementMarquee(
              key: ValueKey<String>('announcement_marquee_${marqueeTopic.id}'),
              topic: marqueeTopic,
              onTap: marqueeTopic.action == null
                  ? null
                  : () {
                      unawaited(
                        _handleTopicAction(
                          marqueeTopic.action!,
                          topic: marqueeTopic,
                        ),
                      );
                    },
              onDismissed: marqueeTopic.dismissingAction == null
                  ? null
                  : () {
                      unawaited(
                        _handleTopicAction(
                          marqueeTopic.dismissingAction!,
                          topic: marqueeTopic,
                        ),
                      );
                    },
            ),
          ),
        ...bannerTopics.map(
          (bannerTopic) => AnnouncementBanner(
            key: ValueKey<String>('announcement_banner_${bannerTopic.id}'),
            topic: bannerTopic,
            onTap: bannerTopic.action == null
                ? null
                : () {
                    unawaited(
                      _handleTopicAction(
                        bannerTopic.action!,
                        topic: bannerTopic,
                      ),
                    );
                  },
            onDismissed: bannerTopic.dismissingAction == null
                ? null
                : () {
                    unawaited(
                      _handleTopicAction(
                        bannerTopic.dismissingAction!,
                        topic: bannerTopic,
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }
}

int _compareAnnouncementTopics(
    AnnouncementTopic left, AnnouncementTopic right) {
  final priorityComparison = right.priorityValue.compareTo(left.priorityValue);
  if (priorityComparison != 0) {
    return priorityComparison;
  }

  final startDateComparison = left.startDate.compareTo(right.startDate);
  if (startDateComparison != 0) {
    return startDateComparison;
  }

  return left.id.compareTo(right.id);
}

Future<bool> _defaultAnnouncementLinkOpener(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.platformDefault);
}
