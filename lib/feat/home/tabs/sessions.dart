import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/theme/app_theme.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/providers/providers.dart';
import 'package:vagina/utils/duration_formatter.dart';
import 'package:vagina/feat/session/screens/session_detail.dart';
import 'package:vagina/repositories/repository_factory.dart';

/// セッション履歴タブ - 通話履歴を表示
class SessionsTab extends ConsumerStatefulWidget {
  const SessionsTab({super.key});

  @override
  ConsumerState<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<SessionsTab> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSessionIds.clear();
      }
    });
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _selectAll(List<CallSession> sessions) {
    setState(() {
      _selectedSessionIds.clear();
      _selectedSessionIds.addAll(sessions.map((s) => s.id));
    });
  }

  void _invertSelection(List<CallSession> sessions) {
    setState(() {
      final allIds = sessions.map((s) => s.id).toSet();
      final newSelection = allIds.difference(_selectedSessionIds);
      _selectedSessionIds.clear();
      _selectedSessionIds.addAll(newSelection);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedSessionIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('選択した${_selectedSessionIds.length}件のセッションを削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final sessionRepo = RepositoryFactory.callSessions;
      for (final id in _selectedSessionIds) {
        await sessionRepo.delete(id);
      }

      setState(() {
        _selectedSessionIds.clear();
        _isSelectionMode = false;
      });

      ref.invalidate(refreshableCallSessionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(refreshableCallSessionsProvider);
    
    // セッション保存完了通知を監視してリストを自動更新
    ref.listen<AsyncValue<String>>(sessionSavedProvider, (_, state) {
      state.whenData((_) {
        ref.invalidate(refreshableCallSessionsProvider);
      });
    });

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラー: $error'),
      ),
      data: (sessions) {
        return Column(
          children: [
            if (_isSelectionMode)
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Text(
                      '${_selectedSessionIds.length}件選択中',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _selectAll(sessions),
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('全選択'),
                    ),
                    TextButton.icon(
                      onPressed: () => _invertSelection(sessions),
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: const Text('反転'),
                    ),
                    IconButton(
                      onPressed: _selectedSessionIds.isNotEmpty ? _deleteSelected : null,
                      icon: const Icon(Icons.delete),
                      color: AppTheme.errorColor,
                    ),
                    IconButton(
                      onPressed: _toggleSelectionMode,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionItem(BuildContext context, CallSession session) {
    final isSelected = _selectedSessionIds.contains(session.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(session.id),
              )
            : const Icon(Icons.phone, color: AppTheme.primaryColor),
        title: Text(DurationFormatter.formatRelativeDate(session.startTime, includeTime: true)),
        subtitle: Text(DurationFormatter.formatDurationCompact(session.duration)),
        trailing: _isSelectionMode ? null : const Icon(Icons.chevron_right),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(session.id);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SessionDetailScreen(sessionId: session.id),
              ),
            );
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedSessionIds.add(session.id);
            });
          }
        },
      ),
    );
  }
}
