import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/text_agent_service.dart';
import '../models/text_agent.dart';
import '../repositories/repository_factory.dart';
import 'providers.dart';

// ============================================================================
// Text Agent Providers
// ============================================================================

/// Text agent service provider
final textAgentServiceProvider = Provider<TextAgentService>((ref) {
  final service = TextAgentService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Available text agents list provider
final availableTextAgentsProvider = Provider<List<TextAgent>>((ref) {
  final service = ref.watch(textAgentServiceProvider);
  return service.listAvailableAgents();
});

/// Stored text agents provider (from repository)
final storedTextAgentsProvider = FutureProvider<List<TextAgent>>((ref) async {
  return await RepositoryFactory.textAgents.getAll();
});

/// Text agents refresh trigger provider
final textAgentsRefreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

/// Auto-refreshable text agents provider
final refreshableTextAgentsProvider = FutureProvider<List<TextAgent>>((ref) async {
  // Watch refresh trigger
  ref.watch(textAgentsRefreshProvider);
  return await RepositoryFactory.textAgents.getAll();
});

/// Selected text agent ID provider
final selectedTextAgentIdProvider = NotifierProvider<SelectedTextAgentNotifier, String?>(
  SelectedTextAgentNotifier.new,
);

/// Selected text agent ID notifier
class SelectedTextAgentNotifier extends Notifier<String?> {
  @override
  String? build() => 'gpt-4o'; // Default to gpt-4o

  void select(String? agentId) {
    state = agentId;
  }

  void clear() {
    state = null;
  }
}
