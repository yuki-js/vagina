import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/feat/call/models/active_file.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/widgets/notepad_content_renderer.dart';

class NotepadPane extends StatefulWidget {
  final VoidCallback onBackPressed;
  final bool hideBackButton;
  final CallService callService;

  const NotepadPane({
    super.key,
    required this.onBackPressed,
    this.hideBackButton = false,
    required this.callService,
  });

  @override
  State<NotepadPane> createState() => _NotepadPaneState();
}

class _NotepadPaneState extends State<NotepadPane> {
  final TextEditingController _editorController = TextEditingController();

  StreamSubscription<CallState>? _stateSubscription;
  StreamSubscription<List<ActiveFile>>? _activeFilesSubscription;

  List<_NotepadTabData> _tabs = const <_NotepadTabData>[];
  String? _selectedTabId;
  String? _currentTabId;
  bool _isEditing = false;
  String _editedContent = '';
  bool _isLoading = true;
  String? _errorMessage;

  _NotepadTabData? get _selectedTab {
    final selectedId = _selectedTabId;
    if (selectedId == null) {
      return null;
    }

    for (final tab in _tabs) {
      if (tab.id == selectedId) {
        return tab;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _bindCallService(widget.callService);
  }

  @override
  void didUpdateWidget(covariant NotepadPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.callService, widget.callService)) {
      _bindCallService(widget.callService);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _activeFilesSubscription?.cancel();
    _editorController.dispose();
    super.dispose();
  }

  void _bindCallService(CallService service) {
    _stateSubscription?.cancel();
    _activeFilesSubscription?.cancel();
    _activeFilesSubscription = null;

    setState(_resetViewState);

    _stateSubscription = service.states.listen(
      _onCallStateChanged,
      onError: (_, __) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).callNotepadLoadFailed;
        });
      },
    );

    _onCallStateChanged(service.state);
  }

  void _onCallStateChanged(CallState state) {
    if (!mounted) {
      return;
    }

    if (state == CallState.uninitialized) {
      _activeFilesSubscription?.cancel();
      _activeFilesSubscription = null;
      setState(_resetViewState);
      return;
    }

    if (state == CallState.disposed) {
      _activeFilesSubscription?.cancel();
      _activeFilesSubscription = null;
      setState(() {
        _isLoading = false;
        _tabs = const <_NotepadTabData>[];
        _selectedTabId = null;
        _errorMessage = null;
        _resetEditingState();
      });
      return;
    }

    if (_activeFilesSubscription != null) {
      return;
    }

    _bindActiveFilesStream();
  }

  void _bindActiveFilesStream() {
    final callService = widget.callService;

    try {
      final initialFiles = callService.notepadService.listActive();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _applyActiveFiles(initialFiles);
      });

      _activeFilesSubscription = callService.activeFilesStream.listen(
        (files) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoading = false;
            _errorMessage = null;
            _applyActiveFiles(files);
          });
        },
        onError: (_, __) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocalizations.of(context).callNotepadLoadFailed;
          });
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
  }

  void _applyActiveFiles(List<ActiveFile> files) {
    final nextTabs = files
        .map(
          (file) => _NotepadTabData(
            id: file.path,
            title: file.title,
            content: file.content,
          ),
        )
        .toList(growable: false);

    final previousSelected = _selectedTabId;
    final hasPreviousSelection = previousSelected != null &&
        nextTabs.any((tab) => tab.id == previousSelected);

    _tabs = nextTabs;
    _selectedTabId = hasPreviousSelection
        ? previousSelected
        : (nextTabs.isNotEmpty ? nextTabs.first.id : null);

    _handleTabChanged(_selectedTabId);
  }

  void _handleTabChanged(String? nextTabId) {
    if (_currentTabId == nextTabId) {
      return;
    }
    if (_isEditing) {
      _resetEditingState();
    }
    _currentTabId = nextTabId;
  }

  void _selectTab(String tabId) {
    setState(() {
      _selectedTabId = tabId;
      _handleTabChanged(tabId);
    });
  }

  void _toggleEditing(String tabId) {
    final selectedTab = _selectedTab;
    if (selectedTab == null || selectedTab.id != tabId) {
      return;
    }

    if (_isEditing && _editedContent != selectedTab.content) {
      _runFireAndForget(
        widget.callService.notepadService
            .update(selectedTab.id, _editedContent),
        errorMessage: AppLocalizations.of(context).callNotepadSaveFailed,
      );
    }

    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _editedContent = selectedTab.content;
        _editorController.value = TextEditingValue(
          text: _editedContent,
          selection: TextSelection.collapsed(offset: _editedContent.length),
        );
      }
    });
  }

  void _closeTab(String tabId) {
    if (_isEditing && _selectedTabId == tabId) {
      setState(_resetEditingState);
    }

    _runFireAndForget(
      _persistAndCloseTab(tabId),
      errorMessage: AppLocalizations.of(context).callNotepadCloseFailed,
    );
  }

  void _onEditedContentChanged(String value) {
    _editedContent = value;
  }

  Future<void> _persistAndCloseTab(String tabId) async {
    final service = widget.callService.notepadService;
    final activeContent = service.getActive(tabId);
    if (activeContent != null) {
      await service.write(tabId, activeContent);
    }
    await service.close(tabId);
  }

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

  void _resetViewState() {
    _tabs = const <_NotepadTabData>[];
    _selectedTabId = null;
    _currentTabId = null;
    _isLoading = true;
    _errorMessage = null;
    _resetEditingState();
  }

  void _resetEditingState() {
    _isEditing = false;
    _editedContent = '';
    _editorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedTab = _selectedTab;

    return Column(
      children: [
        _NotepadHeader(
          onBackPressed: widget.onBackPressed,
          hideBackButton: widget.hideBackButton,
          title: l10n.callNotepadTitle,
          backLabel: l10n.callNotepadBackToCall,
        ),
        _NotepadTabBar(
          tabs: _tabs,
          selectedTabId: _selectedTabId,
          onTabSelected: _selectTab,
        ),
        Expanded(
          child: _isLoading
              ? _NotepadEmptyState(
                  title: l10n.callNotepadLoadingTitle,
                  message: l10n.callNotepadLoadingMessage,
                )
              : _errorMessage != null
                  ? _NotepadEmptyState(
                      title: _errorMessage!,
                      message: l10n.callNotepadRetryMessage,
                    )
                  : selectedTab == null
                      ? _NotepadEmptyState(
                          title: l10n.callNotepadNoOpenNotesTitle,
                          message: l10n.callNotepadNoOpenNotesMessage,
                        )
                      : _NotepadContentShell(
                          tab: selectedTab,
                          isEditing: _isEditing,
                          editingContent: _editedContent,
                          editorController: _editorController,
                          onEditedContentChanged: _onEditedContentChanged,
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
  final String title;
  final String backLabel;

  const _NotepadHeader({
    required this.onBackPressed,
    required this.hideBackButton,
    required this.title,
    required this.backLabel,
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
                    backLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
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
  final String editingContent;
  final TextEditingController editorController;
  final ValueChanged<String> onEditedContentChanged;
  final VoidCallback onEditToggle;
  final VoidCallback onClose;

  const _NotepadContentShell({
    required this.tab,
    required this.isEditing,
    required this.editingContent,
    required this.editorController,
    required this.onEditedContentChanged,
    required this.onEditToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                    tooltip: isEditing
                        ? l10n.callNotepadActionSave
                        : l10n.callNotepadActionEdit,
                    onTap: onEditToggle,
                  ),
                  const SizedBox(width: 8),
                  _HeaderActionButton(
                    icon: Icons.close,
                    tooltip: l10n.callActionClose,
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
              child: !isEditing && tab.content.trim().isEmpty
                  ? _NotepadEmptyState(
                      title: l10n.callNotepadTabEmptyTitle,
                      message: l10n.callNotepadTabEmptyMessage(tab.title),
                    )
                  : NotepadContentRenderer(
                      path: tab.id,
                      content: isEditing ? editingContent : tab.content,
                      isEditing: isEditing,
                      editorController: editorController,
                      onContentChanged: onEditedContentChanged,
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
