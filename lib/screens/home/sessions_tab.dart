import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/call_session.dart';
import '../session_detail_screen.dart';

/// Sessions tab - shows call history
class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire up with sessions provider
    // For now, show empty state
    final sessions = <CallSession>[]; // TODO: Get from provider

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'セッション履歴',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '過去の通話履歴を確認',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Session list or empty state
        if (sessions.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '通話履歴がまだありません',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...sessions.map((session) => _buildSessionItem(context, session)),
      ],
    );
  }

  Widget _buildSessionItem(BuildContext context, CallSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.phone, color: AppTheme.primaryColor),
        title: Text(_formatDateTime(session.startTime)),
        subtitle: Text(_formatDuration(session.duration)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SessionDetailScreen(session: session),
            ),
          );
        },
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
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
