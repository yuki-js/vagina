import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';

final textAgentsProvider = FutureProvider<List<TextAgent>>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getAllTextAgents();
});

final selectedTextAgentIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getSelectedTextAgentId();
});
