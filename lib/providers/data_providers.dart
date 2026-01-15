import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_session.dart';
import '../models/speed_dial.dart';
import '../models/notepad_tab.dart';
import '../repositories/repository_factory.dart';
import 'core_providers.dart';

// ============================================================================
// Data Providers - Simplified
// ============================================================================

class RefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final speedDialsRefreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

final refreshableSpeedDialsProvider = FutureProvider<List<SpeedDial>>((ref) async {
  ref.watch(speedDialsRefreshProvider);
  return await RepositoryFactory.speedDials.getAll();
});

final callSessionsRefreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

final refreshableCallSessionsProvider = FutureProvider<List<CallSession>>((ref) async {
  ref.watch(callSessionsRefreshProvider);
  return await RepositoryFactory.callSessions.getAll();
});

final notepadTabsProvider = StreamProvider<List<NotepadTab>>((ref) {
  return ref.read(notepadServiceProvider).tabsStream;
});

final selectedNotepadTabIdProvider = StreamProvider<String?>((ref) {
  return ref.read(notepadServiceProvider).selectedTabStream;
});
