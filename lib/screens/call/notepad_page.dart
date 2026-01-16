import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../models/notepad_tab.dart';
import '../../components/notepad_content_renderer.dart';
import '../../components/notepad_empty_state.dart';
import '../../components/call/notepad_header.dart';
import '../../components/call/notepad_tab_bar.dart';

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
    if (_isEditing &&
        selectedTab != null &&
        _editedContent != selectedTab.content) {
      // Save changes when exiting edit mode
      ref
          .read(notepadServiceProvider)
          .updateTab(selectedTab.id, content: _editedContent);
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
            NotepadHeader(
              onBackPressed: widget.onBackPressed,
              selectedTab: selectedTab,
              isEditing: _isEditing,
              onEditToggle: () => _toggleEdit(selectedTab),
              editedContent: _editedContent,
              hideBackButton: widget.hideBackButton,
            ),

            // Tab bar (if tabs exist)
            if (tabs.isNotEmpty)
              NotepadTabBar(
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
          NotepadHeader(
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
          NotepadHeader(
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
