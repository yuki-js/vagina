import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Session detail segment - info/details view.
class SessionDetailInfoSegment extends ConsumerWidget {
  final CallSession session;

  const SessionDetailInfoSegment({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<SpeedDial?>(
      future: _loadSpeedDial(ref),
      builder: (context, snapshot) {
        final speedDial = snapshot.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報セクション
              _buildSectionHeader(l10n.sessionDetailBasicInformation),
              const SizedBox(height: 8),
              _buildInfoCard([
                _buildInfoRow(
                  l10n.sessionDetailStartTime,
                  _formatDateTime(context, session.startTime),
                ),
                if (session.endTime != null)
                  _buildInfoRow(
                    l10n.sessionDetailEndTime,
                    _formatDateTime(context, session.endTime!),
                  ),
                _buildInfoRow(
                  l10n.sessionDetailCallDuration,
                  _formatDuration(context, session.duration),
                ),
                _buildInfoRow(
                  l10n.sessionDetailMessageCount,
                  l10n.sessionDetailMessageCountValue(session.chatMessages.length),
                ),
                _buildInfoRow(
                  l10n.callPaneNotepad,
                  l10n.sessionDetailNotepadCountValue(
                    session.notepadTabs?.length ?? 0,
                  ),
                ),
                if (session.endContext != null &&
                    session.endContext!.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildEndContextRow(context, session.endContext!),
                ],
              ]),

              const SizedBox(height: 24),

              // スピードダイヤル情報セクション
              _buildSectionHeader(l10n.sessionDetailSpeedDialSettings),
              const SizedBox(height: 8),
              if (speedDial != null)
                _buildSpeedDialCard(context, speedDial)
              else if (session.speedDialId != SpeedDial.defaultId)
                // Non-default SpeedDial was deleted
                _buildInfoCard([
                  _buildInfoRow(l10n.sessionDetailId, session.speedDialId),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.sessionDetailSpeedDialDeleted,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ])
              else
                // Default SpeedDial should always exist - show error if it doesn't
                _buildInfoCard([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.sessionDetailDefaultSpeedDialMissing,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]),

              const SizedBox(height: 24),

              // サマリーセクション（チャット内容の概要）
              _buildSectionHeader(l10n.sessionDetailConversationSummary),
              const SizedBox(height: 8),
              _buildSummaryCard(context, session),
            ],
          ),
        );
      },
    );
  }

  Future<SpeedDial?> _loadSpeedDial(WidgetRef ref) async {
    final repository = ref.read(speedDialRepositoryProvider);
    return await repository.getById(session.speedDialId);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.lightTextPrimary,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTextSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndContextRow(BuildContext context, String endContext) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).sessionDetailEndReason,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              endContext,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.lightTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialCard(BuildContext context, SpeedDial speedDial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (speedDial.iconEmoji != null) ...[
                Text(
                  speedDial.iconEmoji!,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  speedDial.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(AppLocalizations.of(context).speedDialConfigVoiceLabel,
              speedDial.voice),
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context).speedDialConfigSystemPromptLabel}:',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              speedDial.systemPrompt.length > 200
                  ? '${speedDial.systemPrompt.substring(0, 200)}...'
                  : speedDial.systemPrompt,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, CallSession session) {
    final l10n = AppLocalizations.of(context);
    final messageCount = session.chatMessages.length;
    final notepadCount = session.notepadTabs?.length ?? 0;

    String summary;
    if (messageCount == 0) {
      summary = l10n.sessionDetailSummaryNone;
    } else if (messageCount < 5) {
      summary = l10n.sessionDetailSummaryShort(messageCount);
    } else if (messageCount < 20) {
      summary = l10n.sessionDetailSummaryMedium(messageCount);
    } else {
      summary = l10n.sessionDetailSummaryLong(messageCount);
    }

    if (notepadCount > 0) {
      summary += '\n${l10n.sessionDetailSummaryDocumentsCreated(notepadCount)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTextSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        summary,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.lightTextSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final locale = AppLocalizations.of(context).localeName;
    return DateFormat.yMd(locale).add_Hms().format(value);
  }

  String _formatDuration(BuildContext context, int seconds) {
    final l10n = AppLocalizations.of(context);
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return l10n.sessionDetailDurationValue(minutes, remainingSeconds);
  }
}
