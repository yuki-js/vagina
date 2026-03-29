import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/session/screens/session_detail.dart';
import 'package:vagina/feat/session/state/session_history_providers.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/utils/duration_formatter.dart';

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

    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedSessionIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homeSessionsDeleteConfirmTitle),
        content: Text(
          l10n.homeSessionsDeleteConfirmBody(selectedCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCommonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: Text(l10n.settingsCommonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final sessionRepo = ref.read(callSessionRepositoryProvider);
      for (final id in _selectedSessionIds) {
        await sessionRepo.delete(id);
      }

      setState(() {
        _selectedSessionIds.clear();
        _isSelectionMode = false;
      });

      ref.invalidate(callSessionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.homeSessionsDeleteSuccess(selectedCount),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionsAsync = ref.watch(callSessionsProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(l10n.homeSessionsLoadError(error.toString())),
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
                      l10n.homeSessionsSelectedCount(_selectedSessionIds.length),
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
                      label: Text(l10n.homeSessionsSelectAll),
                    ),
                    TextButton.icon(
                      onPressed: () => _invertSelection(sessions),
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: Text(l10n.homeSessionsInvertSelection),
                    ),
                    IconButton(
                      onPressed: _selectedSessionIds.isNotEmpty
                          ? _deleteSelected
                          : null,
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
              child: sessions.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionItem(context, sessions[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.homeSessionsEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeSessionsEmptyMessage,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, CallSession session) {
    final isSelected = _selectedSessionIds.contains(session.id);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        color: Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(session.id),
              )
            : const Icon(Icons.phone, color: AppTheme.primaryColor),
        title: Text(
          DurationFormatter.formatRelativeDate(session.startTime,
              includeTime: true),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          DurationFormatter.formatDurationCompact(session.duration),
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        trailing: _isSelectionMode
            ? null
            : Icon(
                Icons.chevron_right,
                color: AppTheme.lightTextSecondary,
              ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(session.id);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    SessionDetailScreen(sessionId: session.id),
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
