import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';

final textAgentsProvider = FutureProvider<List<TextAgentInfo>>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getAllTextAgents();
});

final selectedTextAgentIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getSelectedTextAgentId();
});
