import 'dart:async';
import '../models/artifact_tab.dart';
import 'log_service.dart';

/// Service for managing artifact tabs
/// 
/// Manages the state of artifact tabs that display tool outputs
/// meant for human consumption (e.g., generated documents, images)
class ArtifactService {
  static const _tag = 'ArtifactService';
  
  /// Internal list of artifact tabs
  final List<ArtifactTab> _tabs = [];
  
  /// ID of the currently selected tab
  String? _selectedTabId;
  
  /// Stream controller for tab state changes
  final _tabsController = StreamController<List<ArtifactTab>>.broadcast();
  
  /// Stream controller for selected tab changes
  final _selectedTabController = StreamController<String?>.broadcast();
  
  /// Counter for generating unique IDs
  int _idCounter = 0;

  /// Stream of artifact tabs
  Stream<List<ArtifactTab>> get tabsStream => _tabsController.stream;
  
  /// Stream of selected tab ID
  Stream<String?> get selectedTabStream => _selectedTabController.stream;
  
  /// Get current tabs (snapshot)
  List<ArtifactTab> get tabs => List.unmodifiable(_tabs);
  
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
    
    final tab = ArtifactTab(
      id: id,
      title: title ?? _generateTitleFromContent(content, mimeType),
      content: content,
      mimeType: mimeType,
      createdAt: now,
      updatedAt: now,
    );
    
    _tabs.add(tab);
    _selectedTabId = id;
    
    _notifyTabsChanged();
    _notifySelectedTabChanged();
    
    logService.info(_tag, 'Created tab: $id (${tab.title})');
    return id;
  }

  /// Update an existing tab's content
  /// Returns true if successful, false if tab not found
  bool updateTab(String tabId, {String? content, String? title, String? mimeType}) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      logService.warn(_tag, 'Tab not found: $tabId');
      return false;
    }
    
    final oldTab = _tabs[index];
    final newContent = content ?? oldTab.content;
    _tabs[index] = oldTab.copyWith(
      content: newContent,
      title: title ?? (content != null ? _generateTitleFromContent(newContent, oldTab.mimeType) : null),
      mimeType: mimeType,
      updatedAt: DateTime.now(),
    );
    
    _notifyTabsChanged();
    logService.info(_tag, 'Updated tab: $tabId');
    return true;
  }

  /// Close a tab
  /// Returns true if successful, false if tab not found
  bool closeTab(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) {
      logService.warn(_tag, 'Tab not found: $tabId');
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
    logService.info(_tag, 'Closed tab: $tabId');
    return true;
  }

  /// Select a tab
  void selectTab(String? tabId) {
    if (tabId != null && !_tabs.any((t) => t.id == tabId)) {
      logService.warn(_tag, 'Cannot select non-existent tab: $tabId');
      return;
    }
    
    if (_selectedTabId != tabId) {
      _selectedTabId = tabId;
      _notifySelectedTabChanged();
    }
  }

  /// Get a tab by ID
  ArtifactTab? getTab(String tabId) {
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
    logService.info(_tag, 'Cleared all tabs');
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
    logService.info(_tag, 'ArtifactService disposed');
  }
}
