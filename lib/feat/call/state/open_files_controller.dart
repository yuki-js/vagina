import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/models/open_file_tab.dart';
import 'package:vagina/feat/callv2/models/active_file.dart';

class OpenFilesState {
  static const _unset = Object();

  final List<OpenFileTab> tabs;
  final String? selectedTabId;

  const OpenFilesState({
    required this.tabs,
    required this.selectedTabId,
  });

  /// Copy state.
  ///
  /// `selectedTabId` uses a sentinel so callers can omit it without
  /// accidentally clearing the selection.
  OpenFilesState copyWith({
    List<OpenFileTab>? tabs,
    Object? selectedTabId = _unset,
  }) {
    return OpenFilesState(
      tabs: tabs ?? this.tabs,
      selectedTabId: identical(selectedTabId, _unset)
          ? this.selectedTabId
          : selectedTabId as String?,
    );
  }

  OpenFileTab? get selectedTab {
    final id = selectedTabId;
    if (id == null) return null;
    for (final t in tabs) {
      if (t.id == id) return t;
    }
    return null;
  }
}

final openFilesStateProvider =
    StreamProvider.autoDispose<OpenFilesState>((ref) {
  final callService = ref.watch(callServiceProvider);

  final controller = StreamController<OpenFilesState>.broadcast();
  List<OpenFileTab> convert(List<ActiveFile> files) {
    final now = DateTime.now();
    return files
        .map(
          (file) => OpenFileTab(
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
  var current = OpenFilesState(
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
});
