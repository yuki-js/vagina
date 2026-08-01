import 'package:flutter/foundation.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/noop_global_hotkey_service.dart';
import 'package:vagina/services/platform/windows_global_hotkey_service.dart';
import 'package:vagina/utils/platform_compat.dart';

/// Represents the transition state of a global hotkey binding.
enum GlobalHotkeyTransition {
  /// The hotkey was pressed.
  down,

  /// The hotkey was released.
  up,
}

/// Abstract base class for platform-specific global hotkey services.
///
/// Provides methods to set and monitor global hotkey bindings, with support for
/// keyboard modifiers (Ctrl, Shift, Alt, Meta). On Windows, uses a low-level
/// keyboard hook (WH_KEYBOARD_LL). On other platforms, returns false for
/// isSupported and provides no-op implementations.
abstract class GlobalHotkeyService {
  /// Whether this platform supports global hotkey operations.
  bool get isSupported;

  /// A broadcast stream of hotkey transition events (down/up).
  ///
  /// Only emits transitions when the bound key state changes.
  /// Never emits repeated "down" events for key auto-repeat.
  /// Does not emit events when the VAGINA app itself is in the foreground.
  Stream<GlobalHotkeyTransition> get transitions;

  /// Sets the global hotkey binding.
  ///
  /// If [binding] is null, clears any existing binding.
  /// If binding.primaryLogicalKey cannot be converted to a platform VK code,
  /// does nothing (binding remains unset).
  ///
  /// Modifier requirements are matched as a **subset**, mirroring
  /// [PushToTalkKeyBinding.matchesPressedKeys]: a modifier listed by the
  /// binding must be held, while a modifier it does not list is simply not
  /// checked. Extra modifiers held by the user never suppress the hotkey.
  Future<void> setBinding(PushToTalkKeyBinding? binding);

  /// Whether [binding] can actually be registered on this platform.
  ///
  /// False when the primary key has no equivalent in the platform's key
  /// numbering, and always false where global hotkeys are unsupported. Callers
  /// use this to avoid installing a hook that could never match.
  bool supportsBinding(PushToTalkKeyBinding binding);

  /// Activates or deactivates the global hotkey hook.
  ///
  /// Returns true if the operation succeeded (hook installed/removed as needed).
  /// Returns false if the operation failed (e.g., hook already active, system error).
  Future<bool> setActive(bool active);

  /// Cleans up resources associated with this service.
  Future<void> dispose();
}

/// Factory function to create a platform-appropriate GlobalHotkeyService.
///
/// Returns WindowsGlobalHotkeyService on Windows, NoopGlobalHotkeyService otherwise.
GlobalHotkeyService createGlobalHotkeyService() {
  if (kIsWeb) {
    return NoopGlobalHotkeyService();
  }

  if (PlatformCompat.isWindows) {
    return WindowsGlobalHotkeyService();
  }

  return NoopGlobalHotkeyService();
}
