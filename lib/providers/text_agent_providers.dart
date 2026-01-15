import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/text_agent.dart';

final availableTextAgentsProvider = Provider<List<TextAgent>>((ref) {
  return const [
    TextAgent(
      id: 'gpt-4o',
      name: 'GPT-4o',
      description: 'OpenAI GPT-4o - Fast and capable general-purpose model',
      modelIdentifier: 'gpt-4o',
      capabilities: ['general', 'reasoning', 'coding'],
    ),
    TextAgent(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      description: 'OpenAI GPT-4o Mini - Fast and efficient for simple tasks',
      modelIdentifier: 'gpt-4o-mini',
      capabilities: ['general', 'fast'],
    ),
    TextAgent(
      id: 'o1',
      name: 'o1',
      description: 'OpenAI o1 - Advanced reasoning model',
      modelIdentifier: 'o1',
      capabilities: ['reasoning', 'complex-problems'],
    ),
    TextAgent(
      id: 'o1-mini',
      name: 'o1 Mini',
      description: 'OpenAI o1 Mini - Efficient reasoning',
      modelIdentifier: 'o1-mini',
      capabilities: ['reasoning'],
    ),
  ];
});

final selectedTextAgentIdProvider = NotifierProvider<SelectedTextAgentNotifier, String?>(
  SelectedTextAgentNotifier.new,
);

class SelectedTextAgentNotifier extends Notifier<String?> {
  @override
  String? build() => 'gpt-4o';
  void select(String? agentId) => state = agentId;
  void clear() => state = null;
}
