import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/models/call_session.dart';

part 'session_history_providers.g.dart';

/// Call session history list.
///
/// Refresh pattern:
/// - call `ref.invalidate(callSessionsProvider)` after deleting sessions.
@riverpod
Future<List<CallSession>> callSessions(Ref ref) async {
  final repo = ref.watch(callSessionRepositoryProvider);
  return repo.getAll();
}
