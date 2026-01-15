import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// OOBE (Out of Box Experience) Local Providers
// ============================================================================
// These providers are scoped to the onboarding flow.
// They manage temporary state during the setup process.

/// Current OOBE step (local to OOBE flow)
final oobeCurrentStepProvider = StateProvider<int>((ref) => 0);

/// OOBE completion status (local to OOBE flow)
final oobeCompletedProvider = StateProvider<bool>((ref) => false);

/// Temporary API key during manual setup (local to manual setup screen)
final oobeApiKeyProvider = StateProvider<String?>((ref) => null);

/// OOBE setup method selection (local to OOBE flow)
enum OOBESetupMethod { diveIn, manual }

final oobeSetupMethodProvider = StateProvider<OOBESetupMethod?>((ref) => null);

/// Permissions grant status (local to permissions screen)
final oobePermissionsGrantedProvider = StateProvider<Map<String, bool>>((ref) => {
  'microphone': false,
  'notifications': false,
});

/// OOBE navigation can proceed (local to OOBE flow)
final oobeCanProceedProvider = Provider<bool>((ref) {
  final currentStep = ref.watch(oobeCurrentStepProvider);
  final setupMethod = ref.watch(oobeSetupMethodProvider);
  final apiKey = ref.watch(oobeApiKeyProvider);
  final permissions = ref.watch(oobePermissionsGrantedProvider);
  
  switch (currentStep) {
    case 0: // Welcome screen
      return true;
    case 1: // Setup method selection
      return setupMethod != null;
    case 2: // Authentication or Dive In
      if (setupMethod == OOBESetupMethod.manual) {
        return apiKey != null && apiKey.isNotEmpty;
      }
      return true;
    case 3: // Permissions
      return permissions['microphone'] == true;
    default:
      return true;
  }
});
