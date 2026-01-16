import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/services/notepad_service.dart';

part 'notepad_providers.g.dart';

@Riverpod(keepAlive: true)
NotepadService notepadService(Ref ref) {
  final service = NotepadService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
Stream<List<NotepadTab>> notepadTabs(Ref ref) {
  final notepadService = ref.watch(notepadServiceProvider);
  return notepadService.tabsStream;
}

@riverpod
Stream<String?> selectedNotepadTabId(Ref ref) {
  final notepadService = ref.watch(notepadServiceProvider);
  return notepadService.selectedTabStream;
}
