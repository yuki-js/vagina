import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/call_session.dart';
import '../../components/historical_chat_view.dart';
import '../../components/historical_notepad_view.dart';
import '../../repositories/repository_factory.dart';
import '../../utils/duration_formatter.dart';

/// Session detail screen showing chat and notepad from a past session
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
  int _selectedSegment = 0; // 0: Chat, 1: Notepad

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
                child: CircularProgressIndicator(),
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
            // Session info header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DurationFormatter.formatRelativeDate(session.startTime, includeTime: true),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DurationFormatter.formatCallDuration(session.duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented control - using SegmentedButton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('チャット'),
                    icon: Icon(Icons.chat_bubble_outline),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('ノートパッド'),
                    icon: Icon(Icons.article_outlined),
                  ),
                ],
                selected: {_selectedSegment},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedSegment = newSelection.first;
                  });
                },
              ),
            ),

            // Content area - Historical views
            Expanded(
              child: _selectedSegment == 0
                  ? HistoricalChatView(
                      chatMessages: session.chatMessages,
                    )
                  : HistoricalNotepadView(
                      notepadTabs: session.notepadTabs,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
