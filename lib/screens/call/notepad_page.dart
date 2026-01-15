import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/notepad_tab.dart';
import '../../components/notepad/notepad_content_renderer.dart';
import '../../components/notepad/notepad_empty_state.dart';
import '../../components/notepad/notepad_action_bar.dart';

/// Artifact page widget - displays artifact tabs and their content
class NotepadPage extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const NotepadPage({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  ConsumerState<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends ConsumerState<NotepadPage> {
  bool _isEditing = false;
  String _editedContent = '';
  String? _currentTabId;

  void _toggleEdit(NotepadTab? selectedTab) {
    if (_isEditing && selectedTab != null && _editedContent != selectedTab.content) {
      // Save changes when exiting edit mode
      ref.read(notepadServiceProvider).updateTab(selectedTab.id, content: _editedContent);
    }
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing && selectedTab != null) {
        _editedContent = selectedTab.content;
      }
    });
  }

  void _onContentChanged(String newContent) {
    _editedContent = newContent;
  }

  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(notepadTabsProvider);
    final selectedTabIdAsync = ref.watch(selectedNotepadTabIdProvider);
    final notepadService = ref.read(notepadServiceProvider);

    return tabsAsync.when(
      data: (tabs) {
        final selectedId = selectedTabIdAsync.value;
        final selectedTab = selectedId != null 
            ? tabs.where((t) => t.id == selectedId).firstOrNull
            : null;
        
        // Reset editing state when tab changes (based on tab ID change)
        if (_currentTabId != selectedId && _isEditing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isEditing = false;
                _editedContent = '';
                _currentTabId = selectedId;
              });
            }
          });
        } else if (_currentTabId != selectedId) {
          _currentTabId = selectedId;
        }

        return Column(
          children: [
            // Header with menu
            _NotepadHeader(
              onBackPressed: widget.onBackPressed,
              selectedTab: selectedTab,
              isEditing: _isEditing,
              onEditToggle: () => _toggleEdit(selectedTab),
              editedContent: _editedContent,
              hideBackButton: widget.hideBackButton,
            ),

            // Tab bar (if tabs exist)
            if (tabs.isNotEmpty)
              _NotepadTabBar(
                tabs: tabs,
                selectedTabId: selectedId,
                onTabSelected: (tabId) {
                  notepadService.selectTab(tabId);
                },
                onTabClosed: (tabId) {
                  notepadService.closeTab(tabId);
                },
              ),

            // Content area
            Expanded(
              child: tabs.isEmpty
                  ? const NotepadEmptyState()
                  : selectedTab == null
                      ? const NotepadEmptyState()
                      : NotepadContentRenderer(
                          key: ValueKey('${selectedTab.id}_$_isEditing'),
                          tab: selectedTab,
                          isEditing: _isEditing,
                          onContentChanged: _onContentChanged,
                        ),
            ),
          ],
        );
      },
      loading: () => Column(
        children: [
          _NotepadHeader(
            onBackPressed: widget.onBackPressed,
            selectedTab: null,
            isEditing: false,
            onEditToggle: () {},
            editedContent: '',
            hideBackButton: widget.hideBackButton,
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
      error: (_, __) => Column(
        children: [
          _NotepadHeader(
            onBackPressed: widget.onBackPressed,
            selectedTab: null,
            isEditing: false,
            onEditToggle: () {},
            editedContent: '',
            hideBackButton: widget.hideBackButton,
          ),
          Expanded(
            child: Center(
              child: Text(
                'ノートパッドの読み込みに失敗しました',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artifact header with navigation to call and more menu
class _NotepadHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final NotepadTab? selectedTab;
  final bool isEditing;
  final VoidCallback onEditToggle;
  final String editedContent;
  final bool hideBackButton;

  const _NotepadHeader({
    required this.onBackPressed,
    required this.selectedTab,
    required this.isEditing,
    required this.onEditToggle,
    required this.editedContent,
    this.hideBackButton = false,
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
          if (selectedTab != null)
            Consumer(
              builder: (context, ref, child) {
                return NotepadMoreMenu(
                  content: isEditing ? editedContent : selectedTab!.content,
                  isEditing: isEditing,
                  onEditToggle: onEditToggle,
                  showEditButton: selectedTab!.mimeType != 'text/html',
                  canUndo: selectedTab!.canUndo,
                  canRedo: selectedTab!.canRedo,
                  onUndo: () {
                    final service = ref.read(notepadServiceProvider);
                    service.undo(selectedTab!.id);
                  },
                  onRedo: () {
                    final service = ref.read(notepadServiceProvider);
                    service.redo(selectedTab!.id);
                  },
                );
              },
            )
          else
            const SizedBox(width: 48), // Balance for the back button
        ],
      ),
    );
  }
}

/// Tab bar showing artifact tabs
class _NotepadTabBar extends StatelessWidget {
  final List<NotepadTab> tabs;
  final String? selectedTabId;
  final void Function(String) onTabSelected;
  final void Function(String) onTabClosed;

  const _NotepadTabBar({
    required this.tabs,
    required this.selectedTabId,
    required this.onTabSelected,
    required this.onTabClosed,
  });

  @override
  Widget build(BuildContext context) {
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
            child: _NotepadTabItem(
              tab: tab,
              isSelected: isSelected,
              onTap: () => onTabSelected(tab.id),
              onClose: () => onTabClosed(tab.id),
            ),
          );
        },
      ),
    );
  }
}

/// Individual tab item
class _NotepadTabItem extends StatelessWidget {
  final NotepadTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _NotepadTabItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getMimeTypeIcon(tab.mimeType),
              size: 16,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                tab.title,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMimeTypeIcon(String mimeType) {
    switch (mimeType) {
      case 'text/markdown':
        return Icons.article;
      case 'text/html':
        return Icons.code;
      case 'text/plain':
      default:
        return Icons.description;
    }
  }
}
