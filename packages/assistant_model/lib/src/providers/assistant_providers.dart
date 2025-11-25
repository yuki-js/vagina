import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assistant_config.dart';

/// Provider for the assistant configuration
final assistantConfigProvider =
    StateNotifierProvider<AssistantConfigNotifier, AssistantConfig>((ref) {
  return AssistantConfigNotifier();
});

/// Notifier for assistant configuration state
class AssistantConfigNotifier extends StateNotifier<AssistantConfig> {
  AssistantConfigNotifier() : super(const AssistantConfig());

  /// Update the assistant name
  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  /// Update the assistant instructions
  void updateInstructions(String instructions) {
    state = state.copyWith(instructions: instructions);
  }

  /// Update the assistant voice
  void updateVoice(String voice) {
    state = state.copyWith(voice: voice);
  }

  /// Reset to default configuration
  void reset() {
    state = const AssistantConfig();
  }
}
