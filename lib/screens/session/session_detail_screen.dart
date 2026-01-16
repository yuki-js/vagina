import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/call_session.dart';
import '../../components/historical_chat_view.dart';
import '../../components/historical_notepad_view.dart';
import '../../components/adaptive_widgets.dart';
import '../../components/session/session_info_view.dart';
import '../../repositories/repository_factory.dart';

/// セッション詳細画面 - 過去のセッションのチャットとノートパッドを表示
class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
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
        return SessionInfoView(session: session);
      case 1:
        return HistoricalChatView(chatMessages: session.chatMessages);
      case 2:
        return HistoricalNotepadView(notepadTabs: session.notepadTabs);
      default:
        return const SizedBox.shrink();
    }
  }
}
