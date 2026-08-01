import 'package:flutter/services.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';

/// Maps Flutter's [LogicalKeyboardKey] to Windows Virtual Key (VK) codes.
///
/// The table is keyed by the [LogicalKeyboardKey] constants themselves rather
/// than by their numeric `keyId`. [LogicalKeyboardKey] implements `==` and
/// `hashCode` in terms of `keyId`, so a `LogicalKeyboardKey(id)` reconstructed
/// from storage looks up the same entry as the corresponding constant. Keying
/// on raw ids (or on strings derived from them) is error prone: non-printable
/// keys use 11-digit ids such as `0x00200000100`, and small hand-written
/// constants collide with real printable keys (for example `0x7b` is `{`, not
/// `f1`).
///
/// The map is `final` rather than `const`: Dart forbids `const` map keys whose
/// type overrides `==`, and [LogicalKeyboardKey] does.
///
/// See: https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
final Map<LogicalKeyboardKey, int>
_logicalKeyToVirtualKeyCode = Map<LogicalKeyboardKey, int>.unmodifiable(
  <LogicalKeyboardKey, int>{
    // Letters (A-Z: 0x41-0x5A).
    LogicalKeyboardKey.keyA: 0x41,
    LogicalKeyboardKey.keyB: 0x42,
    LogicalKeyboardKey.keyC: 0x43,
    LogicalKeyboardKey.keyD: 0x44,
    LogicalKeyboardKey.keyE: 0x45,
    LogicalKeyboardKey.keyF: 0x46,
    LogicalKeyboardKey.keyG: 0x47,
    LogicalKeyboardKey.keyH: 0x48,
    LogicalKeyboardKey.keyI: 0x49,
    LogicalKeyboardKey.keyJ: 0x4A,
    LogicalKeyboardKey.keyK: 0x4B,
    LogicalKeyboardKey.keyL: 0x4C,
    LogicalKeyboardKey.keyM: 0x4D,
    LogicalKeyboardKey.keyN: 0x4E,
    LogicalKeyboardKey.keyO: 0x4F,
    LogicalKeyboardKey.keyP: 0x50,
    LogicalKeyboardKey.keyQ: 0x51,
    LogicalKeyboardKey.keyR: 0x52,
    LogicalKeyboardKey.keyS: 0x53,
    LogicalKeyboardKey.keyT: 0x54,
    LogicalKeyboardKey.keyU: 0x55,
    LogicalKeyboardKey.keyV: 0x56,
    LogicalKeyboardKey.keyW: 0x57,
    LogicalKeyboardKey.keyX: 0x58,
    LogicalKeyboardKey.keyY: 0x59,
    LogicalKeyboardKey.keyZ: 0x5A,

    // Digits (0-9: 0x30-0x39).
    LogicalKeyboardKey.digit0: 0x30,
    LogicalKeyboardKey.digit1: 0x31,
    LogicalKeyboardKey.digit2: 0x32,
    LogicalKeyboardKey.digit3: 0x33,
    LogicalKeyboardKey.digit4: 0x34,
    LogicalKeyboardKey.digit5: 0x35,
    LogicalKeyboardKey.digit6: 0x36,
    LogicalKeyboardKey.digit7: 0x37,
    LogicalKeyboardKey.digit8: 0x38,
    LogicalKeyboardKey.digit9: 0x39,

    // Function keys (F1-F24: 0x70-0x87).
    LogicalKeyboardKey.f1: 0x70,
    LogicalKeyboardKey.f2: 0x71,
    LogicalKeyboardKey.f3: 0x72,
    LogicalKeyboardKey.f4: 0x73,
    LogicalKeyboardKey.f5: 0x74,
    LogicalKeyboardKey.f6: 0x75,
    LogicalKeyboardKey.f7: 0x76,
    LogicalKeyboardKey.f8: 0x77,
    LogicalKeyboardKey.f9: 0x78,
    LogicalKeyboardKey.f10: 0x79,
    LogicalKeyboardKey.f11: 0x7A,
    LogicalKeyboardKey.f12: 0x7B,
    LogicalKeyboardKey.f13: 0x7C,
    LogicalKeyboardKey.f14: 0x7D,
    LogicalKeyboardKey.f15: 0x7E,
    LogicalKeyboardKey.f16: 0x7F,
    LogicalKeyboardKey.f17: 0x80,
    LogicalKeyboardKey.f18: 0x81,
    LogicalKeyboardKey.f19: 0x82,
    LogicalKeyboardKey.f20: 0x83,
    LogicalKeyboardKey.f21: 0x84,
    LogicalKeyboardKey.f22: 0x85,
    LogicalKeyboardKey.f23: 0x86,
    LogicalKeyboardKey.f24: 0x87,

    // Other common keys.
    LogicalKeyboardKey.space: 0x20,
    LogicalKeyboardKey.tab: 0x09,
    LogicalKeyboardKey.escape: 0x1B,
    LogicalKeyboardKey.enter: 0x0D,
    LogicalKeyboardKey.backspace: 0x08,
    LogicalKeyboardKey.capsLock: 0x14,

    // Arrow keys (0x25-0x28).
    LogicalKeyboardKey.arrowLeft: 0x25,
    LogicalKeyboardKey.arrowUp: 0x26,
    LogicalKeyboardKey.arrowRight: 0x27,
    LogicalKeyboardKey.arrowDown: 0x28,

    // Modifier keys. These entries are required so that a modifier-only binding
    // (see PushToTalkKeyBinding.isModifierOnly) can be registered as a hotkey.
    LogicalKeyboardKey.controlLeft: 0xA2,
    LogicalKeyboardKey.controlRight: 0xA3,
    LogicalKeyboardKey.shiftLeft: 0xA0,
    LogicalKeyboardKey.shiftRight: 0xA1,
    LogicalKeyboardKey.altLeft: 0xA4,
    LogicalKeyboardKey.altRight: 0xA5,
    LogicalKeyboardKey.metaLeft: 0x5B,
    LogicalKeyboardKey.metaRight: 0x5C,
  },
);

/// Gets the Windows Virtual Key code for a given [LogicalKeyboardKey].
///
/// Returns the VK code if the key is supported, null otherwise.
int? virtualKeyCodeForLogicalKey(LogicalKeyboardKey key) {
  return _logicalKeyToVirtualKeyCode[key];
}

/// Converts a [PushToTalkKeyBinding] to a Windows platform-specific payload.
///
/// Returns a Map with the required fields for the native global hotkey system:
/// - `primaryVirtualKeyCode`: the VK code for the primary key.
/// - `requiresControl`, `requiresShift`, `requiresAlt`, `requiresMeta`: the
///   required modifier state.
///
/// The `requires*` flags use **subset matching**, matching
/// [PushToTalkKeyBinding.matchesPressedKeys]: `true` means "this modifier must
/// be held", while `false` means "don't care" — it does **not** mean "this
/// modifier must not be held". The native side must therefore only reject a
/// candidate when a flag is `true` and the corresponding modifier is not
/// pressed, and must never reject because an unrequested modifier happens to
/// be down.
///
/// This is load bearing for modifier-only bindings: [PushToTalkKeyBinding]
/// clears `modifiers` when the primary key is itself a modifier, so a
/// "Left Ctrl" binding is sent as `primaryVirtualKeyCode: 0xA2` with
/// `requiresControl: false`. Under exact matching that binding could never
/// fire, because pressing Left Ctrl necessarily makes the control modifier
/// active. Subset matching also keeps global push-to-talk consistent with the
/// in-app push-to-talk handling, which tolerates extra modifiers.
///
/// Returns null if the primary key cannot be converted to a VK code.
Map<String, Object?>? windowsGlobalHotkeyPayloadForBinding(
  PushToTalkKeyBinding binding,
) {
  final vkCode = virtualKeyCodeForLogicalKey(binding.primaryLogicalKey);
  if (vkCode == null) {
    return null;
  }

  return <String, Object?>{
    'primaryVirtualKeyCode': vkCode,
    'requiresControl': binding.modifiers.contains(
      PushToTalkKeyModifier.control,
    ),
    'requiresShift': binding.modifiers.contains(PushToTalkKeyModifier.shift),
    'requiresAlt': binding.modifiers.contains(PushToTalkKeyModifier.alt),
    'requiresMeta': binding.modifiers.contains(PushToTalkKeyModifier.meta),
  };
}
