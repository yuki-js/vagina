import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/call_session.dart';
import '../../../models/speed_dial.dart';
import '../../../repositories/repository_factory.dart';
import '../../../utils/duration_formatter.dart';

/// Session information view - displays detailed session information
class SessionInfoView extends StatelessWidget {
  final CallSession session;

  const SessionInfoView({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpeedDial?>(
      future: _loadSpeedDial(),
      builder: (context, snapshot) {
        final speedDial = snapshot.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic information section
              _buildSectionHeader('基本情報'),
              const SizedBox(height: 8),
              _buildInfoCard([
                _buildInfoRow(
                    '開始時刻',
                    DurationFormatter.formatJapaneseDateTime(
                        session.startTime)),
                if (session.endTime != null)
                  _buildInfoRow(
                      '終了時刻',
                      DurationFormatter.formatJapaneseDateTime(
                          session.endTime!)),
                _buildInfoRow('通話時間',
                    DurationFormatter.formatCallDuration(session.duration)),
                _buildInfoRow('メッセージ数', '${session.chatMessages.length}件'),
                _buildInfoRow('ノートパッド', '${session.notepadTabs?.length ?? 0}件'),
              ]),

              const SizedBox(height: 24),

              // Speed dial information section
              _buildSectionHeader('スピードダイヤル設定'),
              const SizedBox(height: 8),
              if (speedDial != null)
                _buildSpeedDialCard(speedDial)
              else if (session.speedDialId != SpeedDial.defaultId)
                // Non-default SpeedDial was deleted
                _buildInfoCard([
                  _buildInfoRow('ID', session.speedDialId),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '※スピードダイヤルが削除された可能性があります',
                      style: TextStyle(
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'エラー: デフォルトスピードダイヤルが見つかりません',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]),

              const SizedBox(height: 24),

              // Summary section (brief overview of chat content)
              _buildSectionHeader('会話サマリー'),
              const SizedBox(height: 8),
              _buildSummaryCard(session),
            ],
          ),
        );
      },
    );
  }

  Future<SpeedDial?> _loadSpeedDial() async {
    return await RepositoryFactory.speedDials.getById(session.speedDialId);
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

  Widget _buildSpeedDialCard(SpeedDial speedDial) {
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
          _buildInfoRow('音声', speedDial.voice),
          const SizedBox(height: 8),
          Text(
            'システムプロンプト:',
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

  Widget _buildSummaryCard(CallSession session) {
    // Generate simple summary from chat messages
    final messageCount = session.chatMessages.length;
    final hasNotepad = (session.notepadTabs?.length ?? 0) > 0;

    String summary;
    if (messageCount == 0) {
      summary = '会話履歴がありません';
    } else if (messageCount < 5) {
      summary = '短い会話セッション（$messageCount件のメッセージ）';
    } else if (messageCount < 20) {
      summary = '中程度の会話セッション（$messageCount件のメッセージ）';
    } else {
      summary = '長い会話セッション（$messageCount件のメッセージ）';
    }

    if (hasNotepad) {
      summary += '\n${session.notepadTabs!.length}件のドキュメントが作成されました';
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
}
