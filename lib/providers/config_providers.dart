import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assistant_config.dart';
import 'repository_providers.dart';

// ============================================================================
// Assistant & Config Providers
// ============================================================================

/// APIキー存在確認のプロバイダ
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final config = ref.read(configRepositoryProvider);
  return await config.hasApiKey();
});

/// APIキーのプロバイダ
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final config = ref.read(configRepositoryProvider);
  return await config.getApiKey();
});

/// アシスタント設定のプロバイダ
final assistantConfigProvider =
    NotifierProvider<AssistantConfigNotifier, AssistantConfig>(AssistantConfigNotifier.new);

/// アシスタント設定の通知クラス
class AssistantConfigNotifier extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();

  /// アシスタント名を更新
  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  /// アシスタントの指示を更新
  void updateInstructions(String instructions) {
    state = state.copyWith(instructions: instructions);
  }

  /// アシスタントの声を更新
  void updateVoice(String voice) {
    state = state.copyWith(voice: voice);
  }

  /// デフォルト設定にリセット
  void reset() {
    state = const AssistantConfig();
  }
}
