import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/speed_dial.dart';

// ============================================================================
// Speed Dial Config Screen Local Providers
// ============================================================================
// These providers are scoped to the speed dial configuration screen.
// They manage temporary editing state before saving to repository.

/// Editing speed dial provider (local to config screen)
final editingSpeedDialProvider = StateProvider<SpeedDial?>((ref) => null);

/// Temporary name during edit (local to config screen)
final tempSpeedDialNameProvider = StateProvider<String>((ref) {
  final editing = ref.watch(editingSpeedDialProvider);
  return editing?.name ?? '';
});

/// Temporary system prompt during edit (local to config screen)
final tempSpeedDialPromptProvider = StateProvider<String>((ref) {
  final editing = ref.watch(editingSpeedDialProvider);
  return editing?.systemPrompt ?? '';
});

/// Temporary voice during edit (local to config screen)
final tempSpeedDialVoiceProvider = StateProvider<String>((ref) {
  final editing = ref.watch(editingSpeedDialProvider);
  return editing?.voice ?? 'alloy';
});

/// Temporary icon during edit (local to config screen)
final tempSpeedDialIconProvider = StateProvider<String>((ref) {
  final editing = ref.watch(editingSpeedDialProvider);
  return editing?.icon ?? 'phone';
});

/// Validation error messages (local to config screen)
final speedDialValidationErrorsProvider = StateProvider<Map<String, String?>>((ref) => {});

/// Is saving state (local to config screen)
final speedDialSavingProvider = StateProvider<bool>((ref) => false);
