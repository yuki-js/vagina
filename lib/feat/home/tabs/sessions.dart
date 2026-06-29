import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const double _loadMoreExtent = 240;

  final Set<String> _selectedSessionIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final remaining = _scrollController.position.extentAfter;
    if (remaining <= _loadMoreExtent) {
      ref.read(sessionHistoryControllerProvider.notifier).loadMore();
    }
  }

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
      _selectedSessionIds
        ..clear()
        ..addAll(sessions.map((session) => session.id));
    });
  }

  void _invertSelection(List<CallSession> sessions) {
    setState(() {
      final allIds = sessions.map((session) => session.id).toSet();
      final newSelection = allIds.difference(_selectedSessionIds);
      _selectedSessionIds
        ..clear()
        ..addAll(newSelection);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedSessionIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final ids = _selectedSessionIds.toList(growable: false);
    final selectedCount = ids.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.homeSessionsDeleteConfirmTitle),
        content: Text(l10n.homeSessionsDeleteConfirmBody(selectedCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCommonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(l10n.settingsCommonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(sessionHistoryControllerProvider.notifier).bulkDelete(ids);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSessionIds.clear();
      _isSelectionMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.homeSessionsDeleteSuccess(selectedCount))),
    );
  }

  Future<void> _refresh() {
    setState(() {
      _selectedSessionIds.clear();
      _isSelectionMode = false;
    });
    return ref.read(sessionHistoryControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sessionHistoryControllerProvider);

    if (state.isInitialLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError && state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Text(l10n.homeSessionsLoadError(state.error.toString())),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isSelectionMode)
          _SelectionToolbar(
            selectedCount: _selectedSessionIds.length,
            sessions: state.items,
            onSelectAll: _selectAll,
            onInvertSelection: _invertSelection,
            onDeleteSelected: _selectedSessionIds.isNotEmpty
                ? _deleteSelected
                : null,
            onClose: _toggleSelectionMode,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: state.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: _buildEmptyState(context),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount:
                        state.items.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const _BottomLoadingIndicator();
                      }
                      return _buildSessionItem(context, state.items[index]);
                    },
                  ),
          ),
        ),
      ],
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeSessionsEmptyMessage,
            style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, CallSession session) {
    final isSelected = _selectedSessionIds.contains(session.id);

    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(session.id),
                )
              : const Icon(Icons.phone, color: AppTheme.primaryColor),
          title: Text(
            DurationFormatter.formatRelativeDate(
              session.startedAt,
              includeTime: true,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            DurationFormatter.formatDurationCompact(session.duration),
            style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
          ),
          trailing: _isSelectionMode
              ? null
              : Icon(Icons.chevron_right, color: AppTheme.lightTextSecondary),
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
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final List<CallSession> sessions;
  final ValueChanged<List<CallSession>> onSelectAll;
  final ValueChanged<List<CallSession>> onInvertSelection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback onClose;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.sessions,
    required this.onSelectAll,
    required this.onInvertSelection,
    required this.onDeleteSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            l10n.homeSessionsSelectedCount(selectedCount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => onSelectAll(sessions),
            icon: const Icon(Icons.select_all, size: 18),
            label: Text(l10n.homeSessionsSelectAll),
          ),
          TextButton.icon(
            onPressed: () => onInvertSelection(sessions),
            icon: const Icon(Icons.swap_vert, size: 18),
            label: Text(l10n.homeSessionsInvertSelection),
          ),
          IconButton(
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete),
            color: AppTheme.errorColor,
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _BottomLoadingIndicator extends StatelessWidget {
  const _BottomLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.homeSessionsLoadingMore,
              style: TextStyle(
                color: AppTheme.lightTextSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
