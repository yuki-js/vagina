import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Settings Screen Local Providers
// ============================================================================
// These providers are scoped to the settings screen.
// They manage temporary UI state for settings configuration.

/// Selected settings section index (local to settings screen)
final selectedSettingsSectionProvider = StateProvider<int>((ref) => 0);

/// API key visibility toggle (local to settings screen)
final apiKeyVisibleProvider = StateProvider<bool>((ref) => false);

/// Temporary API key during edit (local to settings screen)
final tempApiKeyProvider = StateProvider<String?>((ref) => null);

/// Settings save in progress (local to settings screen)
final settingsSavingProvider = StateProvider<bool>((ref) => false);

/// Settings validation errors (local to settings screen)
final settingsValidationErrorsProvider = StateProvider<Map<String, String?>>((ref) => {});

/// Show advanced settings (local to settings screen)
final showAdvancedSettingsProvider = StateProvider<bool>((ref) => false);

/// Developer mode toggle (local to settings screen)
final developerModeEnabledProvider = StateProvider<bool>((ref) => false);
