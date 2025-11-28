import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/notepad_tab.dart';
import 'notepad_content_renderer.dart';
import 'notepad_empty_state.dart';

/// Artifact page widget - displays artifact tabs and their content
class NotepadPage extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;

  const NotepadPage({
    super.key,
    required this.onBackPressed,
  });

  @override
  ConsumerState<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends ConsumerState<NotepadPage> {
  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(notepadTabsProvider);
    final selectedTabIdAsync = ref.watch(selectedNotepadTabIdProvider);
    final notepadService = ref.read(notepadServiceProvider);

    return Column(
      children: [
        // Header
        _NotepadHeader(onBackPressed: widget.onBackPressed),

        // Tab bar (if tabs exist)
        tabsAsync.when(
          data: (tabs) {
            if (tabs.isEmpty) {
              return const SizedBox.shrink();
            }
            
            final selectedId = selectedTabIdAsync.value;
            return _NotepadTabBar(
              tabs: tabs,
              selectedTabId: selectedId,
              onTabSelected: (tabId) {
                notepadService.selectTab(tabId);
              },
              onTabClosed: (tabId) {
                notepadService.closeTab(tabId);
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Content area
        Expanded(
          child: tabsAsync.when(
            data: (tabs) {
              if (tabs.isEmpty) {
                return const NotepadEmptyState();
              }
              
              final selectedId = selectedTabIdAsync.value;
              final selectedTab = selectedId != null 
                  ? tabs.where((t) => t.id == selectedId).firstOrNull
                  : null;
              
              if (selectedTab == null) {
                return const NotepadEmptyState();
              }
              
              return NotepadContentRenderer(
                tab: selectedTab,
                onContentChanged: (newContent) {
                  notepadService.updateTab(selectedTab.id, content: newContent);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (_, __) => Center(
              child: Text(
                'ノートパッドの読み込みに失敗しました',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Artifact header with navigation to call
class _NotepadHeader extends StatelessWidget {
  final VoidCallback onBackPressed;

  const _NotepadHeader({required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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
          const SizedBox(width: 80), // Balance for the back button
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
