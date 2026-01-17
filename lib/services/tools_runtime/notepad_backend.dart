import 'dart:collection';

import 'package:vagina/models/notepad_tab.dart';

/// Placeholder per-call notepad state owner.
///
/// No production wiring yet; this is a minimal in-memory container.
class NotepadBackend {
  final List<NotepadTab> _tabs;

  NotepadBackend({Iterable<NotepadTab>? initialTabs})
      : _tabs = List<NotepadTab>.from(initialTabs ?? const []);

  /// Current snapshot of tabs.
  UnmodifiableListView<NotepadTab> get tabs => UnmodifiableListView(_tabs);

  /// Replaces all tabs.
  set tabs(Iterable<NotepadTab> value) {
    _tabs
      ..clear()
      ..addAll(value);
  }

  /// Returns a tab by ID, or null if not found.
  NotepadTab? getTab(String tabId) {
    for (final tab in _tabs) {
      if (tab.id == tabId) {
        return tab;
      }
    }
    return null;
  }
}
