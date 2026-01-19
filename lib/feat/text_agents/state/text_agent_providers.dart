import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';

part 'text_agent_providers.g.dart';

/// Text agents list.
///
/// Refresh pattern:
/// - call `ref.invalidate(textAgentsProvider)` after create/update/delete.
@riverpod
Future<List<TextAgent>> textAgents(Ref ref) async {
  final repo = ref.watch(textAgentRepositoryProvider);
  return repo.getAll();
}

/// Selected text agent ID.
///
/// Refresh pattern:
/// - call `ref.invalidate(selectedTextAgentIdProvider)` after selection change.
@riverpod
Future<String?> selectedTextAgentId(Ref ref) async {
  final repo = ref.watch(textAgentRepositoryProvider);
  return repo.getSelectedAgentId();
}

/// Selected text agent.
///
/// Derives the selected agent from the list and selected ID.
@riverpod
Future<TextAgent?> selectedTextAgent(Ref ref) async {
  final agents = await ref.watch(textAgentsProvider.future);
  final selectedId = await ref.watch(selectedTextAgentIdProvider.future);

  if (selectedId == null || agents.isEmpty) {
    return null;
  }

  try {
    return agents.firstWhere((agent) => agent.id == selectedId);
  } catch (_) {
    return null;
  }
}

/// Text agent jobs list.
///
/// Refresh pattern:
/// - call `ref.invalidate(textAgentJobsProvider)` after create/update/delete.
@riverpod
Future<List<TextAgentJob>> textAgentJobs(Ref ref) async {
  final repo = ref.watch(textAgentJobRepositoryProvider);
  return repo.getAll();
}

/// Active text agent jobs (non-expired, non-completed, non-failed).
@riverpod
Future<List<TextAgentJob>> activeTextAgentJobs(Ref ref) async {
  final allJobs = await ref.watch(textAgentJobsProvider.future);
  return allJobs.where((job) {
    return job.status == TextAgentJobStatus.pending ||
        job.status == TextAgentJobStatus.running;
  }).toList();
}
