import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/call_session.dart';
import '../../models/speed_dial.dart';
import '../../components/historical_chat_view.dart';
import '../../components/historical_notepad_view.dart';
import '../../components/adaptive_widgets.dart';
import '../../repositories/repository_factory.dart';
import '../../utils/duration_formatter.dart';

/// セッション詳細画面 - 過去のセッションのチャットとノートパッドを表示
class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  int _selectedSegment = 0; // 0: 詳細, 1: チャット, 2: ノートパッド

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CallSession?>(
      future: _loadSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('セッション詳細'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Container(
              decoration: AppTheme.lightBackgroundGradient,
              child: const Center(
                child: AdaptiveProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('セッション詳細'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Container(
              decoration: AppTheme.lightBackgroundGradient,
              child: const Center(
                child: Text('セッションが見つかりません'),
              ),
            ),
          );
        }
        
        final session = snapshot.data!;
        return _buildSessionDetail(session);
      },
    );
  }
  
  Future<CallSession?> _loadSession() async {
    return await RepositoryFactory.callSessions.getById(widget.sessionId);
  }
  
  Widget _buildSessionDetail(CallSession session) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('セッション詳細'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: AppTheme.lightBackgroundGradient,
        child: Column(
          children: [
            // セグメントコントロール - アダプティブウィジェットを使用
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AdaptiveSegmentedControl<int>(
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 4),
                        Text('詳細'),
                      ],
                    ),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 16),
                        SizedBox(width: 4),
                        Text('チャット'),
                      ],
                    ),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.article_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('ノートパッド'),
                      ],
                    ),
                  ),
                },
                groupValue: _selectedSegment,
                onValueChanged: (value) {
                  setState(() {
                    _selectedSegment = value;
                  });
                },
              ),
            ),

            // コンテンツエリア
            Expanded(
              child: _buildContent(session),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent(CallSession session) {
    switch (_selectedSegment) {
      case 0:
        return _SessionInfoView(session: session);
      case 1:
        return HistoricalChatView(chatMessages: session.chatMessages);
      case 2:
        return HistoricalNotepadView(notepadTabs: session.notepadTabs);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// セッション情報ビュー - 詳細情報を表示
class _SessionInfoView extends StatelessWidget {
  final CallSession session;
  
  const _SessionInfoView({required this.session});
  
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
              // 基本情報セクション
              _buildSectionHeader('基本情報'),
              const SizedBox(height: 8),
              _buildInfoCard([
                _buildInfoRow('開始時刻', DurationFormatter.formatJapaneseDateTime(session.startTime)),
                if (session.endTime != null)
                  _buildInfoRow('終了時刻', DurationFormatter.formatJapaneseDateTime(session.endTime!)),
                _buildInfoRow('通話時間', DurationFormatter.formatCallDuration(session.duration)),
                _buildInfoRow('メッセージ数', '${session.chatMessages.length}件'),
                _buildInfoRow('ノートパッド', '${session.notepadTabs?.length ?? 0}件'),
              ]),
              
              const SizedBox(height: 24),
              
              // スピードダイヤル情報セクション
              _buildSectionHeader('スピードダイヤル設定'),
              const SizedBox(height: 8),
              if (speedDial != null)
                _buildSpeedDialCard(speedDial)
              else if (session.speedDialId != null)
                _buildInfoCard([
                  _buildInfoRow('ID', session.speedDialId!),
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
                _buildInfoCard([
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'デフォルト設定を使用',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                ]),
              
              const SizedBox(height: 24),
              
              // サマリーセクション（チャット内容の概要）
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
    if (session.speedDialId == null) return null;
    return await RepositoryFactory.speedDials.getById(session.speedDialId!);
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
    // チャットメッセージから簡単なサマリーを生成
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
