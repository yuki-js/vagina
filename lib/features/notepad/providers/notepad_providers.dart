import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/notepad_service.dart';
import '../../../models/notepad_tab.dart';
import '../../../providers/core_providers.dart';

// ============================================================================
// ノートパッドプロバイダ
// ============================================================================

/// ノートパッドサービスのプロバイダ
final notepadServiceProvider = Provider<NotepadService>((ref) {
  final service = NotepadService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// ノートパッドタブのプロバイダ（ストリーム）
final notepadTabsProvider = StreamProvider<List<NotepadTab>>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return notepadService.tabsStream;
});

/// 選択中のノートパッドタブIDのプロバイダ（ストリーム）
final selectedNotepadTabIdProvider = StreamProvider<String?>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return notepadService.selectedTabStream;
});
