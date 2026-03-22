import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';

class NotepadPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const NotepadPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  State<NotepadPane> createState() => _NotepadPaneState();
}

class _NotepadPaneState extends State<NotepadPane> {
  late final List<_NotepadTabData> _tabs = <_NotepadTabData>[
    const _NotepadTabData(
      id: 'draft-note',
      title: 'draft.md',
      content: '',
    ),
    const _NotepadTabData(
      id: 'ideas-note',
      title: 'ideas.txt',
      content: '',
    ),
    const _NotepadTabData(
      id: 'todo-note',
      title: 'todo.md',
      content: '',
    ),
  ];

  late String _selectedTabId = _tabs.first.id;
  final Set<String> _editingTabIds = <String>{};

  _NotepadTabData? get _selectedTab {
    for (final tab in _tabs) {
      if (tab.id == _selectedTabId) {
        return tab;
      }
    }

    return _tabs.isNotEmpty ? _tabs.first : null;
  }

  void _selectTab(String tabId) {
    setState(() {
      _selectedTabId = tabId;
    });
  }

  void _toggleEditing(String tabId) {
    setState(() {
      if (_editingTabIds.contains(tabId)) {
        _editingTabIds.remove(tabId);
      } else {
        _editingTabIds.add(tabId);
      }
    });
  }

  void _closeTab(String tabId) {
    if (_tabs.isEmpty) {
      return;
    }

    final closingIndex = _tabs.indexWhere((tab) => tab.id == tabId);
    if (closingIndex == -1) {
      return;
    }

    setState(() {
      _tabs.removeAt(closingIndex);
      _editingTabIds.remove(tabId);

      if (_tabs.isEmpty) {
        _selectedTabId = '';
        return;
      }

      if (_selectedTabId == tabId) {
        final nextIndex = closingIndex.clamp(0, _tabs.length - 1);
        _selectedTabId = _tabs[nextIndex].id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = _selectedTab;

    return Column(
      children: [
        _NotepadHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
        ),
        _NotepadTabBar(
          tabs: _tabs,
          selectedTabId: _selectedTabId,
          onTabSelected: _selectTab,
        ),
        Expanded(
          child: selectedTab == null
              ? const _NotepadEmptyState(
                  title: '開いているノートパッドがありません',
                  message: 'ここに開いているノートの内容が表示されます',
                )
              : _NotepadContentShell(
                  tab: selectedTab,
                  isEditing: _editingTabIds.contains(selectedTab.id),
                  onEditToggle: () => _toggleEditing(selectedTab.id),
                  onClose: () => _closeTab(selectedTab.id),
                ),
        ),
      ],
    );
  }
}

class _NotepadHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const _NotepadHeader({
    required this.onBackPressed,
    required this.hideBackButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          if (!hideBackButton)
            GestureDetector(
              onTap: onBackPressed,
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                  Text(
                    '通話画面',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const Expanded(
            child: Center(
              child: Text(
                'ノートパッド',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _NotepadTabBar extends StatelessWidget {
  final List<_NotepadTabData> tabs;
  final String? selectedTabId;
  final ValueChanged<String> onTabSelected;

  const _NotepadTabBar({
    required this.tabs,
    required this.selectedTabId,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = tab.id == selectedTabId;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onTabSelected(tab.id),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.surfaceColor.withValues(alpha: 0.95)
                      : AppTheme.surfaceColor.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.textSecondary.withValues(alpha: 0.25)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotepadContentShell extends StatelessWidget {
  final _NotepadTabData tab;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final VoidCallback onClose;

  const _NotepadContentShell({
    required this.tab,
    required this.isEditing,
    required this.onEditToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.backgroundStart.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textSecondary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tab.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _HeaderActionButton(
                    icon: isEditing ? Icons.save_outlined : Icons.edit_outlined,
                    tooltip: isEditing ? '保存' : '編集',
                    onTap: onEditToggle,
                  ),
                  const SizedBox(width: 8),
                  _HeaderActionButton(
                    icon: Icons.close,
                    tooltip: '閉じる',
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
            ),
            Expanded(
              child: tab.content.trim().isEmpty
                  ? _NotepadEmptyState(
                      title: 'このタブはまだ空です',
                      message: 'ここに ${tab.title} の内容が表示されます',
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        tab.content,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotepadEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _NotepadEmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotepadTabData {
  final String id;
  final String title;
  final String content;

  const _NotepadTabData({
    required this.id,
    required this.title,
    required this.content,
  });
}
