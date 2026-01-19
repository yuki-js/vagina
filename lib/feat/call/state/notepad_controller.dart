import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/models/notepad_tab.dart';

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
      selectedTabId:
          identical(selectedTabId, _unset) ? this.selectedTabId : selectedTabId as String?,
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
  // Get NotepadService from CallService (call-scoped instance)
  final callService = ref.watch(callServiceProvider);
  final service = callService.notepadService;

  final controller = StreamController<NotepadState>.broadcast();
  var current = NotepadState(
    tabs: service.tabs,
    selectedTabId: service.selectedTabId,
  );

  void emit() {
    if (!controller.isClosed) {
      controller.add(current);
    }
  }

  emit();

  final tabsSub = service.tabsStream.listen((tabs) {
    current = current.copyWith(tabs: tabs);
    emit();
  });

  final selectedSub = service.selectedTabStream.listen((selectedId) {
    current = current.copyWith(selectedTabId: selectedId);
    emit();
  });

  ref.onDispose(() async {
    await tabsSub.cancel();
    await selectedSub.cancel();
    await controller.close();
  });

  return controller.stream;
}
