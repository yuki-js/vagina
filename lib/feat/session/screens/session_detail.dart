import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/widgets/realtime_thread_renderer.dart';
import 'package:vagina/feat/session/session_formatters.dart';
import 'package:vagina/feat/session/state/session_history_providers.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/repositories/api_call_session_repository.dart';

/// セッション詳細画面 - 過去のセッション情報を表示
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionDetailTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        color: AppTheme.lightBackgroundStart,
        child: sessionAsync.when(
          loading: () => const Center(
            child: CupertinoActivityIndicator(color: AppTheme.primaryColor),
          ),
          error: (error, stackTrace) => _SessionDetailError(error: error),
          data: (session) {
            if (session == null) {
              return Center(child: Text(l10n.sessionDetailMissing));
            }
            return _SessionDetailContent(session: session);
          },
        ),
      ),
    );
  }
}

class _SessionDetailError extends StatelessWidget {
  final Object error;

  const _SessionDetailError({required this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = error is SavedThreadCannotBeDisplayedException
        ? l10n.sessionDetailSavedThreadCannotBeDisplayed
        : l10n.sessionDetailLoadError(error.toString());

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.lightTextPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailContent extends StatelessWidget {
  final CallSession session;

  const _SessionDetailContent({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final thread = session.thread;
    final visibleItems = thread?.items
        .where((item) => item.isVisible)
        .toList(growable: false);

    return Column(
      children: [
        _SessionMetadataHeader(session: session),
        Expanded(
          child: visibleItems == null || visibleItems.isEmpty
              ? _EmptyThreadState(
                  title: l10n.sessionDetailThreadEmptyTitle,
                  message: l10n.sessionDetailThreadEmptyMessage,
                )
              : RealtimeThreadView(
                  items: thread!.items,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  onToolTap: (item) {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppTheme.surfaceColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => RealtimeThreadToolDetailsSheet(
                        itemId: item.id,
                        initialItems: thread.items,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SessionMetadataHeader extends StatelessWidget {
  final CallSession session;

  const _SessionMetadataHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTextSecondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.sessionDetailMetadataTitle,
                  style: const TextStyle(
                    color: AppTheme.lightTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetadataRow(
            label: l10n.sessionDetailStartTime,
            value: formatSessionDateTime(context, session.startedAt),
          ),
          if (session.endedAt != null)
            _MetadataRow(
              label: l10n.sessionDetailEndTime,
              value: formatSessionDateTime(context, session.endedAt!),
            ),
          _MetadataRow(
            label: l10n.sessionDetailCallDuration,
            value: formatSessionDuration(context, session.duration),
          ),
          _MetadataRow(
            label: l10n.sessionDetailMessageCount,
            value: l10n.sessionDetailMessageCountValue(
              session.visibleThreadItemCount,
            ),
          ),
          if ((session.speedDialId ?? '').isNotEmpty)
            _MetadataRow(
              label: l10n.sessionDetailSpeedDialId,
              value: session.speedDialId!,
            ),
          if ((session.voiceAgentId ?? '').isNotEmpty)
            _MetadataRow(
              label: l10n.sessionDetailVoiceAgentId,
              value: session.voiceAgentId!,
            ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.lightTextSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.lightTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThreadState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyThreadState({required this.title, required this.message});

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
              size: 56,
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.lightTextPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.lightTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
