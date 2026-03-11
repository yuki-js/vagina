import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/models/open_file_state.dart';

part 'notepad_controller.g.dart';

class NotepadState {
  static const _unset = Object();

  final List<NotepadTab> tabs;
  final String? selectedTabId;

  const NotepadState({
    required this.tabs,
    required this.selectedTabId,
  });

  /// Copy state.
  ///
  /// `selectedTabId` uses a sentinel so callers can omit it without
  /// accidentally clearing the selection.
  NotepadState copyWith({
    List<NotepadTab>? tabs,
    Object? selectedTabId = _unset,
  }) {
    return NotepadState(
      tabs: tabs ?? this.tabs,
      selectedTabId: identical(selectedTabId, _unset)
          ? this.selectedTabId
          : selectedTabId as String?,
    );
  }

  NotepadTab? get selectedTab {
    final id = selectedTabId;
    if (id == null) return null;
    for (final t in tabs) {
      if (t.id == id) return t;
    }
    return null;
  }
}

@riverpod
Stream<NotepadState> notepadState(Ref ref) {
  final callService = ref.watch(callServiceProvider);

  final controller = StreamController<NotepadState>.broadcast();
  List<NotepadTab> convert(List<OpenFileState> files) {
    final now = DateTime.now();
    return files
        .map(
          (file) => NotepadTab(
            id: file.path,
            title: file.title,
            content: file.content,
            mimeType: file.mimeType,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
  }

  final initialTabs = convert(callService.openFiles);
  var current = NotepadState(
    tabs: initialTabs,
    selectedTabId: initialTabs.isNotEmpty ? initialTabs.first.id : null,
  );

  void emit() {
    if (!controller.isClosed) {
      controller.add(current);
    }
  }

  emit();

  final tabsSub = callService.openFilesStream.listen((openFiles) {
    final tabs = convert(openFiles);
    final selected = current.selectedTabId;
    final nextSelected = selected != null && tabs.any((t) => t.id == selected)
        ? selected
        : (tabs.isNotEmpty ? tabs.first.id : null);

    current = current.copyWith(tabs: tabs);
    current = current.copyWith(selectedTabId: nextSelected);
    emit();
  });

  ref.onDispose(() async {
    await tabsSub.cancel();
    await controller.close();
  });

  return controller.stream;
}
