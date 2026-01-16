import 'dart:async';
import '../models/notepad_tab.dart';
import 'log_service.dart';

/// Service for managing artifact tabs
///
/// Manages the state of artifact tabs that display tool outputs
/// meant for human consumption (e.g., generated documents, images)
class NotepadService {
  static const _tag = 'NotepadService';

  final LogService _logService;

  /// Internal list of artifact tabs
  final List<NotepadTab> _tabs = [];

  /// ID of the currently selected tab
  String? _selectedTabId;

  /// Stream controller for tab state changes
  final _tabsController = StreamController<List<NotepadTab>>.broadcast();

  /// Stream controller for selected tab changes
  final _selectedTabController = StreamController<String?>.broadcast();

  /// Counter for generating unique IDs
  int _idCounter = 0;

  NotepadService({LogService? logService})
      : _logService = logService ?? LogService();

  /// Stream of artifact tabs
  Stream<List<NotepadTab>> get tabsStream => _tabsController.stream;

  /// Stream of selected tab ID
  Stream<String?> get selectedTabStream => _selectedTabController.stream;

  /// Get current tabs (snapshot)
  List<NotepadTab> get tabs => List.unmodifiable(_tabs);

  /// Get currently selected tab ID
  String? get selectedTabId => _selectedTabId;

  /// Generate a unique tab ID
  String _generateId() {
    _idCounter++;
    return 'artifact_$_idCounter';
  }

  /// Create a new tab with the given content
  /// Returns the tab ID
  String createTab({
    required String content,
    required String mimeType,
    String? title,
  }) {
    final id = _generateId();
    final now = DateTime.now();

    // Initialize history with the initial content
    final initialHistory = [
      EditHistoryEntry(content: content, timestamp: now),
    ];

    final tab = NotepadTab(
      id: id,
      title: title ?? _generateTitleFromContent(content, mimeType),
      content: content,
      mimeType: mimeType,
      createdAt: now,
      updatedAt: now,
      history: initialHistory,
      currentHistoryIndex: 0,
    );

    _tabs.add(tab);
    _selectedTabId = id;

    _notifyTabsChanged();
    _notifySelectedTabChanged();

    _logService.info(_tag, 'Created tab: $id (${tab.title})');
    return id;
  }

  /// Update an existing tab's content
  /// Returns true if successful, false if tab not found
  bool updateTab(String tabId,
      {String? content, String? title, String? mimeType}) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      _logService.warn(_tag, 'Tab not found: $tabId');
      return false;
    }

    final oldTab = _tabs[index];
    final newContent = content ?? oldTab.content;
    final now = DateTime.now();

    // Add to history if content changed
    List<EditHistoryEntry> newHistory = List.from(oldTab.history);
    int newHistoryIndex = oldTab.currentHistoryIndex;

    if (content != null && content != oldTab.content) {
      // Only truncate if we're not at the end (i.e., there's redo history to discard)
      if (oldTab.currentHistoryIndex < oldTab.history.length - 1) {
        newHistory = newHistory.sublist(0, oldTab.currentHistoryIndex + 1);
      }

      // Add new entry
      newHistory.add(EditHistoryEntry(content: content, timestamp: now));
      newHistoryIndex = newHistory.length - 1;
    }

    _tabs[index] = oldTab.copyWith(
      content: newContent,
      title: title ??
          (content != null
              ? _generateTitleFromContent(newContent, oldTab.mimeType)
              : null),
      mimeType: mimeType,
      updatedAt: now,
      history: newHistory,
      currentHistoryIndex: newHistoryIndex,
    );

    _notifyTabsChanged();
    _logService.info(_tag, 'Updated tab: $tabId');
    return true;
  }

  /// Undo the last edit
  /// Returns true if successful, false if cannot undo or tab not found
  bool undo(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      _logService.warn(_tag, 'Tab not found: $tabId');
      return false;
    }

    final tab = _tabs[index];
    if (!tab.canUndo) {
      _logService.warn(_tag, 'Cannot undo: at beginning of history');
      return false;
    }

    final newIndex = tab.currentHistoryIndex - 1;
    final previousContent = tab.history[newIndex].content;

    _tabs[index] = tab.copyWith(
      content: previousContent,
      currentHistoryIndex: newIndex,
      updatedAt: DateTime.now(),
    );

    _notifyTabsChanged();
    _logService.info(_tag, 'Undone edit for tab: $tabId');
    return true;
  }

  /// Redo the previously undone edit
  /// Returns true if successful, false if cannot redo or tab not found
  bool redo(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      _logService.warn(_tag, 'Tab not found: $tabId');
      return false;
    }

    final tab = _tabs[index];
    if (!tab.canRedo) {
      _logService.warn(_tag, 'Cannot redo: at end of history');
      return false;
    }

    final newIndex = tab.currentHistoryIndex + 1;
    final nextContent = tab.history[newIndex].content;

    _tabs[index] = tab.copyWith(
      content: nextContent,
      currentHistoryIndex: newIndex,
      updatedAt: DateTime.now(),
    );

    _notifyTabsChanged();
    _logService.info(_tag, 'Redone edit for tab: $tabId');
    return true;
  }

  /// Close a tab
  /// Returns true if successful, false if tab not found
  bool closeTab(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      _logService.warn(_tag, 'Tab not found: $tabId');
      return false;
    }

    _tabs.removeAt(index);

    // If closing the selected tab, select another one
    if (_selectedTabId == tabId) {
      if (_tabs.isNotEmpty) {
        // Select the previous tab, or the first one if we were at the start
        _selectedTabId = _tabs[index > 0 ? index - 1 : 0].id;
      } else {
        _selectedTabId = null;
      }
      _notifySelectedTabChanged();
    }

    _notifyTabsChanged();
    _logService.info(_tag, 'Closed tab: $tabId');
    return true;
  }

  /// Select a tab
  void selectTab(String? tabId) {
    if (tabId != null && !_tabs.any((t) => t.id == tabId)) {
      _logService.warn(_tag, 'Cannot select non-existent tab: $tabId');
      return;
    }

    if (_selectedTabId != tabId) {
      _selectedTabId = tabId;
      _notifySelectedTabChanged();
    }
  }

  /// Get a tab by ID
  NotepadTab? getTab(String tabId) {
    try {
      return _tabs.firstWhere((t) => t.id == tabId);
    } catch (_) {
      return null;
    }
  }

  /// Get tab content by ID
  String? getTabContent(String tabId) {
    return getTab(tabId)?.content;
  }

  /// Get tab metadata by ID
  Map<String, dynamic>? getTabMetadata(String tabId) {
    return getTab(tabId)?.toMetadata();
  }

  /// List all tabs (for tool API)
  List<Map<String, dynamic>> listTabs() {
    return _tabs.map((t) => t.toMetadata()).toList();
  }

  /// Clear all tabs
  void clearTabs() {
    _tabs.clear();
    _selectedTabId = null;
    _notifyTabsChanged();
    _notifySelectedTabChanged();
    _logService.info(_tag, 'Cleared all tabs');
  }

  void _notifyTabsChanged() {
    _tabsController.add(List.unmodifiable(_tabs));
  }

  void _notifySelectedTabChanged() {
    _selectedTabController.add(_selectedTabId);
  }

  /// Generate a title from content
  String _generateTitleFromContent(String content, String mimeType) {
    // Try to extract title from markdown
    if (mimeType == 'text/markdown') {
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#')) {
          // Remove # and whitespace
          return trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        }
      }
    }

    // Use first line if short enough
    final firstLine = content.split('\n').first.trim();
    if (firstLine.isNotEmpty && firstLine.length <= 30) {
      return firstLine;
    }

    // Default title based on MIME type
    switch (mimeType) {
      case 'text/markdown':
        return 'Markdown Document';
      case 'text/plain':
        return 'Text Document';
      case 'text/html':
        return 'HTML Document';
      default:
        return 'Document';
    }
  }

  /// Dispose the service
  void dispose() {
    _tabsController.close();
    _selectedTabController.close();
    _logService.info(_tag, 'NotepadService disposed');
  }
}
