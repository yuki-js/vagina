import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/state/notepad_controller.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/widgets/notepad_header.dart';
import 'package:vagina/feat/call/widgets/notepad_tab_bar.dart';
import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/feat/call/widgets/notepad_content_renderer.dart';
import 'package:vagina/feat/call/widgets/notepad_empty_state.dart';

/// Artifact page widget - displays artifact tabs and their content
class NotepadPane extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const NotepadPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  ConsumerState<NotepadPane> createState() => _NotepadPaneState();
}

class _NotepadPaneState extends ConsumerState<NotepadPane> {
  bool _isEditing = false;
  String _editedContent = '';
  String? _currentTabId;

  void _toggleEdit(NotepadTab? selectedTab) {
    if (_isEditing &&
        selectedTab != null &&
        _editedContent != selectedTab.content) {
      // Save changes when exiting edit mode
      ref
          .read(callServiceProvider)
          .notepadService
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
    final notepadStateAsync = ref.watch(notepadStateProvider);
    final notepadService = ref.read(callServiceProvider).notepadService;

    return notepadStateAsync.when(
      data: (state) {
        final tabs = state.tabs;
        final selectedId = state.selectedTabId;
        final selectedTab = state.selectedTab;

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
          const Expanded(
            child: Center(
              child: Text(
                'ノートパッドの読み込みに失敗しました',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
