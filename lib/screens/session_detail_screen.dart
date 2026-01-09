import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/call_session.dart';
import '../components/historical_chat_view.dart';
import '../components/historical_notepad_view.dart';

/// Session detail screen showing chat and notepad from a past session
class SessionDetailScreen extends StatefulWidget {
  final CallSession session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  int _selectedSegment = 0; // 0: Chat, 1: Notepad

  @override
  Widget build(BuildContext context) {
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
                    _formatDateTime(widget.session.startTime),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(widget.session.duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.lightTextSecondary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        label: 'チャット',
                        icon: Icons.chat_bubble_outline,
                        isSelected: _selectedSegment == 0,
                        onTap: () => setState(() => _selectedSegment = 0),
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        label: 'ノートパッド',
                        icon: Icons.article_outlined,
                        isSelected: _selectedSegment == 1,
                        onTap: () => setState(() => _selectedSegment = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content area - Historical views
            Expanded(
              child: _selectedSegment == 0
                  ? HistoricalChatView(
                      chatMessages: widget.session.chatMessages,
                    )
                  : HistoricalNotepadView(
                      notepadContent: widget.session.notepadContent,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppTheme.lightTextSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '今日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '通話時間: $minutes分$remainingSeconds秒';
  }
}
