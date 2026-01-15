import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assistant_config.dart';

// ============================================================================
// Config Providers - Simplified
// ============================================================================

/// アシスタント設定のプロバイダ
final assistantConfigProvider =
    NotifierProvider<AssistantConfigNotifier, AssistantConfig>(AssistantConfigNotifier.new);

class AssistantConfigNotifier extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();

  void updateName(String name) => state = state.copyWith(name: name);
  void updateInstructions(String instructions) => state = state.copyWith(instructions: instructions);
  void updateVoice(String voice) => state = state.copyWith(voice: voice);
  void reset() => state = const AssistantConfig();
}
