import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/state/open_files_controller.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/widgets/open_files_header.dart';
import 'package:vagina/feat/call/widgets/open_files_tab_bar.dart';
import 'package:vagina/models/open_file_tab.dart';
import 'package:vagina/feat/call/widgets/open_files_content_renderer.dart';
import 'package:vagina/feat/call/widgets/open_files_empty_state.dart';

/// Open-files pane widget - displays active file tabs and their content.
class OpenFilesPane extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;

  const OpenFilesPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
  });

  @override
  ConsumerState<OpenFilesPane> createState() => _OpenFilesPaneState();
}

class _OpenFilesPaneState extends ConsumerState<OpenFilesPane> {
  bool _isEditing = false;
  String _editedContent = '';
  String? _selectedTabId;
  String? _currentTabId;

  void _runFireAndForget(
    Future<void> operation, {
    required String errorMessage,
  }) {
    unawaited(
      operation.catchError((Object _, StackTrace __) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }),
    );
  }

  void _toggleEdit(OpenFileTab? selectedTab) {
    if (_isEditing &&
        selectedTab != null &&
        _editedContent != selectedTab.content) {
      // Save changes when exiting edit mode
      _runFireAndForget(
        ref
            .read(callServiceProvider)
            .updateOpenFileContent(selectedTab.id, _editedContent),
        errorMessage: 'ファイルの保存に失敗しました',
      );
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
    final openFilesStateAsync = ref.watch(openFilesStateProvider);
    final callService = ref.read(callServiceProvider);

    return openFilesStateAsync.when(
      data: (state) {
        final tabs = state.tabs;
        if (_selectedTabId == null ||
            !tabs.any((tab) => tab.id == _selectedTabId)) {
          _selectedTabId = tabs.isNotEmpty ? tabs.first.id : null;
        }
        final selectedId = _selectedTabId;
        final selectedTab = tabs.where((tab) => tab.id == selectedId).isNotEmpty
            ? tabs.firstWhere((tab) => tab.id == selectedId)
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
            OpenFilesHeader(
              onBackPressed: widget.onBackPressed,
              selectedTab: selectedTab,
              isEditing: _isEditing,
              onEditToggle: () => _toggleEdit(selectedTab),
              editedContent: _editedContent,
              hideBackButton: widget.hideBackButton,
            ),

            // Tab bar (if tabs exist)
            if (tabs.isNotEmpty)
              OpenFilesTabBar(
                tabs: tabs,
                selectedTabId: selectedId,
                onTabSelected: (tabId) {
                  setState(() {
                    _selectedTabId = tabId;
                  });
                },
                onTabClosed: (tabId) {
                  _runFireAndForget(
                    callService.closeOpenFile(tabId),
                    errorMessage: 'ファイルを閉じられませんでした',
                  );
                },
              ),

            // Content area
            Expanded(
              child: tabs.isEmpty
                  ? const OpenFilesEmptyState()
                  : selectedTab == null
                      ? const OpenFilesEmptyState()
                      : OpenFilesContentRenderer(
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
          OpenFilesHeader(
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
          OpenFilesHeader(
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
                'ファイルペインの読み込みに失敗しました',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
