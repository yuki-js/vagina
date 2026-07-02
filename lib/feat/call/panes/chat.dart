import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/widgets/realtime_thread_renderer.dart';

class ChatPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;
  final CallService callService;

  const ChatPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
    required this.callService,
  });

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<RealtimeThread>? _threadSubscription;
  StreamSubscription<RealtimeAdapterConnectionState>?
  _connectionStateSubscription;
  List<RealtimeThreadItem> _items = const <RealtimeThreadItem>[];
  bool _isConnected = false;
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;
  RealtimeService? _boundRealtimeService;

  RealtimeService? get _realtimeService => widget.callService.realtimeService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    _bindRealtimeService(_realtimeService);
  }

  @override
  void didUpdateWidget(covariant ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    final realtimeService = _realtimeService;
    if (identical(_boundRealtimeService, realtimeService)) {
      return;
    }

    _bindRealtimeService(realtimeService);
    setState(() {});
  }

  void _bindRealtimeService(RealtimeService? service) {
    _threadSubscription?.cancel();
    _threadSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _boundRealtimeService = service;

    _items = service?.thread.items ?? const <RealtimeThreadItem>[];
    _isConnected = service?.connectionState.isConnected ?? false;

    if (service == null) {
      return;
    }

    _threadSubscription = service.threadUpdates.listen((thread) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = thread.items;
      });
    });

    _connectionStateSubscription = service.connectionStateUpdates.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = state.isConnected;
      });
    });
  }

  @override
  void dispose() {
    _threadSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isAtBottom = currentScroll >= maxScroll - 50;
    final shouldShowScrollButton = !isAtBottom;

    if (isAtBottom != _isAtBottom ||
        shouldShowScrollButton != _showScrollToBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
        _showScrollToBottom = shouldShowScrollButton;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showToolDetailsSheet(RealtimeThreadItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RealtimeThreadToolDetailsSheet(
        itemId: item.id,
        initialItems: _items,
        realtimeService: _realtimeService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _ChatHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
          title: l10n.callChatTitle,
          backLabel: l10n.callChatBackToCall,
        ),
        Expanded(
          child: _items.isEmpty
              ? _ChatEmptyState(
                  title: l10n.callChatEmptyTitle,
                  message: l10n.callChatEmptyMessage,
                )
              : Builder(
                  builder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_isAtBottom && _scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return Stack(
                      children: [
                        RealtimeThreadView(
                          items: _items,
                          scrollController: _scrollController,
                          onToolTap: _showToolDetailsSheet,
                        ),
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _ScrollToBottomButton(
                                onPressed: _scrollToBottom,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        _ChatInputShell(
          controller: _textController,
          enabled: _isConnected,
          onSend: _handleSendMessage,
          enabledHintText: l10n.callChatInputHintEnabled,
          disabledHintText: l10n.callChatInputHintDisabled,
        ),
      ],
    );
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final callService = widget.callService;
    if (callService.state != CallState.active) {
      return;
    }

    // Send text through CallService to ensure interrupt logic is executed
    callService.sendTextMessage(text);
    _textController.clear();
  }
}

class _ChatHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;
  final String title;
  final String backLabel;

  const _ChatHeader({
    required this.onBackPressed,
    required this.hideBackButton,
    required this.title,
    required this.backLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!hideBackButton) const SizedBox(width: 80),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          if (!hideBackButton)
            GestureDetector(
              onTap: onBackPressed,
              child: Row(
                children: [
                  Text(
                    backLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScrollToBottomButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.callChatScrollToBottom,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _ChatEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _PendingAttachmentKind { image }

final class _PendingAttachment {
  final String id;
  final _PendingAttachmentKind kind;
  final String name;
  final int size;
  final Uint8List bytes;

  const _PendingAttachment({
    required this.id,
    required this.kind,
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class _ChatInputShell extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSend;
  final String enabledHintText;
  final String disabledHintText;

  const _ChatInputShell({
    required this.controller,
    required this.enabled,
    this.onSend,
    required this.enabledHintText,
    required this.disabledHintText,
  });

  @override
  State<_ChatInputShell> createState() => _ChatInputShellState();
}

class _ChatInputShellState extends State<_ChatInputShell> {
  static const int _maxImageAttachmentCount = 4;
  static const int _maxImageAttachmentBytes = 8 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {'jpg', 'jpeg', 'png'};

  final List<_PendingAttachment> _attachments = <_PendingAttachment>[];
  bool _isAddMode = false;
  bool _isPickingImages = false;
  int _nextAttachmentId = 0;

  @override
  void didUpdateWidget(covariant _ChatInputShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.enabled && _isAddMode) {
      _isAddMode = false;
    }
  }

  Future<void> _pickImages() async {
    if (!widget.enabled || _isPickingImages) {
      return;
    }

    final remainingSlots = _maxImageAttachmentCount - _attachments.length;
    if (remainingSlots <= 0) {
      _showSnackBar(
        AppLocalizations.of(
          context,
        ).callChatImageAttachmentLimitExceeded(_maxImageAttachmentCount),
      );
      return;
    }

    setState(() {
      _isPickingImages = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedImageExtensions.toList(growable: false),
        allowMultiple: true,
        withData: true,
      );
      if (!mounted || result == null) {
        return;
      }

      final acceptedAttachments = <_PendingAttachment>[];
      var rejectedForCount = 0;
      var rejectedForFormat = 0;
      var rejectedForSize = 0;
      var rejectedForRead = 0;

      for (final file in result.files) {
        if (acceptedAttachments.length >= remainingSlots) {
          rejectedForCount++;
          continue;
        }

        final bytes = file.bytes;
        if (bytes == null) {
          rejectedForRead++;
          continue;
        }
        if (file.size > _maxImageAttachmentBytes ||
            bytes.length > _maxImageAttachmentBytes) {
          rejectedForSize++;
          continue;
        }
        if (!_isSupportedImageFile(file.name, bytes)) {
          rejectedForFormat++;
          continue;
        }

        acceptedAttachments.add(
          _PendingAttachment(
            id: 'image-${_nextAttachmentId++}',
            kind: _PendingAttachmentKind.image,
            name: file.name,
            size: file.size,
            bytes: bytes,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _attachments.addAll(acceptedAttachments);
        _isAddMode = false;
      });

      _showValidationSnackBars(
        rejectedForCount: rejectedForCount,
        rejectedForFormat: rejectedForFormat,
        rejectedForSize: rejectedForSize,
        rejectedForRead: rejectedForRead,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppLocalizations.of(context).callChatImagePickFailed);
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
        });
      }
    }
  }

  bool _isSupportedImageFile(String name, Uint8List bytes) {
    final extension = name.split('.').last.toLowerCase();
    if (!_allowedImageExtensions.contains(extension)) {
      return false;
    }

    return _hasPngMagicBytes(bytes) || _hasJpegMagicBytes(bytes);
  }

  bool _hasPngMagicBytes(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  bool _hasJpegMagicBytes(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  void _showValidationSnackBars({
    required int rejectedForCount,
    required int rejectedForFormat,
    required int rejectedForSize,
    required int rejectedForRead,
  }) {
    final l10n = AppLocalizations.of(context);

    if (rejectedForCount > 0) {
      _showSnackBar(
        l10n.callChatImageAttachmentLimitExceeded(_maxImageAttachmentCount),
      );
    }
    if (rejectedForFormat > 0) {
      _showSnackBar(l10n.callChatImageUnsupportedFormat);
    }
    if (rejectedForSize > 0) {
      _showSnackBar(l10n.callChatImageTooLarge);
    }
    if (rejectedForRead > 0) {
      _showSnackBar(l10n.callChatImageReadFailed);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((attachment) => attachment.id == id);
    });
  }

  void _toggleAddMode() {
    if (!widget.enabled || _isPickingImages) {
      return;
    }
    setState(() {
      _isAddMode = !_isAddMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_attachments.isNotEmpty) ...[
            _AttachmentPreviewTray(
              attachments: _attachments,
              onRemove: _removeAttachment,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _AttachmentModeButton(
                enabled: widget.enabled && !_isPickingImages,
                isAddMode: _isAddMode,
                onPressed: _toggleAddMode,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isAddMode
                      ? _AttachmentActionRow(
                          key: const ValueKey<String>('attachment-actions'),
                          enabled: widget.enabled && !_isPickingImages,
                          onPickImages: _pickImages,
                        )
                      : _MessageInputRow(
                          key: const ValueKey<String>('message-input'),
                          controller: widget.controller,
                          enabled: widget.enabled,
                          onSend: widget.onSend,
                          enabledHintText: widget.enabledHintText,
                          disabledHintText: widget.disabledHintText,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentModeButton extends StatelessWidget {
  static const double _closedTurns = 0;
  static const double _openTurns = 0.125;

  final bool enabled;
  final bool isAddMode;
  final VoidCallback onPressed;

  const _AttachmentModeButton({
    required this.enabled,
    required this.isAddMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: isAddMode
          ? l10n.callChatCloseAttachmentMenuTooltip
          : l10n.callChatAddAttachmentTooltip,
      onPressed: enabled ? onPressed : null,
      icon: AnimatedRotation(
        turns: isAddMode ? _openTurns : _closedTurns,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Icon(
          Icons.add,
          size: 30,
          color: enabled
              ? AppTheme.textSecondary
              : AppTheme.textSecondary.withValues(alpha: 0.45),
        ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textSecondary,
        disabledForegroundColor: AppTheme.textSecondary.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _MessageInputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSend;
  final String enabledHintText;
  final String disabledHintText;

  const _MessageInputRow({
    super.key,
    required this.controller,
    required this.enabled,
    this.onSend,
    required this.enabledHintText,
    required this.disabledHintText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: enabled ? (_) => onSend?.call() : null,
            decoration: InputDecoration(
              hintText: enabled ? enabledHintText : disabledHintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.backgroundStart,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: enabled ? onSend : null,
          icon: const Icon(Icons.send, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: enabled
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentActionRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPickImages;

  const _AttachmentActionRow({
    super.key,
    required this.enabled,
    required this.onPickImages,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        FilledButton.icon(
          onPressed: enabled ? onPickImages : null,
          icon: const Icon(Icons.image_outlined),
          label: Text(l10n.callChatImageAttachmentAction),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.16),
            foregroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.textSecondary.withValues(
              alpha: 0.12,
            ),
            disabledForegroundColor: AppTheme.textSecondary.withValues(
              alpha: 0.6,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentPreviewTray extends StatelessWidget {
  final List<_PendingAttachment> attachments;
  final ValueChanged<String> onRemove;

  const _AttachmentPreviewTray({
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _ImageAttachmentPreviewCard(
            attachment: attachment,
            onRemove: () => onRemove(attachment.id),
          );
        },
      ),
    );
  }
}

class _ImageAttachmentPreviewCard extends StatelessWidget {
  final _PendingAttachment attachment;
  final VoidCallback onRemove;

  const _ImageAttachmentPreviewCard({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.callChatSelectedImageAttachment(attachment.name),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundStart,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Image.memory(
                    attachment.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported_outlined,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: IconButton.filled(
                tooltip: l10n.callChatRemoveImageAttachmentTooltip,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.72),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(28, 28),
                  fixedSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
