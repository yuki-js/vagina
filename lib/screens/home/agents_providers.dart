import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/text_agent.dart';

final availableTextAgentsProvider = Provider<List<TextAgent>>((ref) {
  return const [
    TextAgent(id: 'gpt-4o', name: 'GPT-4o', description: 'Fast general-purpose', modelIdentifier: 'gpt-4o', capabilities: ['general']),
    TextAgent(id: 'o1', name: 'o1', description: 'Advanced reasoning', modelIdentifier: 'o1', capabilities: ['reasoning']),
  ];
});

final selectedTextAgentIdProvider = NotifierProvider<SelectedTextAgentNotifier, String?>(SelectedTextAgentNotifier.new);

class SelectedTextAgentNotifier extends Notifier<String?> {
  @override
  String? build() => 'gpt-4o';
  void select(String? id) => state = id;
}
