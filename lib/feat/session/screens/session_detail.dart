import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/adaptive_widgets.dart';
import 'package:vagina/feat/session/segments/chat.dart';
import 'package:vagina/feat/session/segments/info.dart';
import 'package:vagina/feat/session/segments/notepad.dart';

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
    final repository = ref.read(callSessionRepositoryProvider);
    return await repository.getById(widget.sessionId);
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
        return SessionDetailInfoSegment(session: session);
      case 1:
        return SessionDetailChatSegment(chatMessages: session.chatMessages);
      case 2:
        return SessionDetailNotepadSegment(notepadTabs: session.notepadTabs);
      default:
        return const SizedBox.shrink();
    }
  }
}
