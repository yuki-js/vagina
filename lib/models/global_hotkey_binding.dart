import 'package:flutter/services.dart';

/// Voice input operations that can be driven by a system-wide hotkey.
///
/// System-wide hotkeys stay available while another application owns keyboard
/// focus, so the user can drive a call without switching windows.
enum GlobalHotkeyAction {
  /// Starts an input turn on key press and sends it on key release.
  pushToTalk,

  /// Starts an input turn on the first press and sends it on the next press.
  pushToTalkToggle,

  /// Discards the input turn that is currently being recorded.
  cancelInput,

  /// Interrupts assistant playback.
  interrupt,

  /// Toggles the microphone mute state.
  muteToggle;

  String get storageValue => name;

  /// Whether the platform has to report key releases for this action.
  ///
  /// Only hold-to-talk distinguishes press from release; every other action
  /// fires once per press, so the platform can skip release tracking.
  bool get tracksKeyRelease => this == GlobalHotkeyAction.pushToTalk;

  static GlobalHotkeyAction? fromStorageValue(String value) {
    for (final action in GlobalHotkeyAction.values) {
      if (action.storageValue == value) {
        return action;
      }
    }
    return null;
  }
}

/// Modifier keys a system-wide hotkey can require.
///
/// [win32Mask] holds the matching Win32 `MOD_*` value expected by
/// `RegisterHotKey`, which is why this enum is separate from the in-app
/// push-to-talk modifiers. Declaration order drives the order the modifiers of
/// a combination are displayed in.
enum GlobalHotkeyModifier {
  control(0x0002, 'Ctrl'),
  shift(0x0004, 'Shift'),
  alt(0x0001, 'Alt'),
  meta(0x0008, 'Win');

  const GlobalHotkeyModifier(this.win32Mask, this.displayToken);

  final int win32Mask;
  final String displayToken;

  String get storageValue => name;

  static GlobalHotkeyModifier? fromStorageValue(String value) {
    for (final modifier in GlobalHotkeyModifier.values) {
      if (modifier.storageValue == value) {
        return modifier;
      }
    }
    return null;
  }
}

/// A single system-wide hotkey, expressed the way the OS registers it.
///
/// The primary key is stored as a platform virtual-key code rather than a
/// Flutter [LogicalKeyboardKey] because the hotkey is owned by the OS, not by
/// the Flutter view. [displayTokens] preserves the labels captured at
/// recording time so settings can render the binding without translating the
/// virtual-key code back.
class GlobalHotkeyBinding {
  static const String _virtualKeyCodeKey = 'virtualKeyCode';
  static const String _modifiersKey = 'modifiers';
  static const String _displayTokensKey = 'displayTokens';

  final int virtualKeyCode;
  final List<GlobalHotkeyModifier> modifiers;
  final List<String> displayTokens;

  const GlobalHotkeyBinding({
    required this.virtualKeyCode,
    required this.modifiers,
    required this.displayTokens,
  });

  /// Combined Win32 `MOD_*` mask for [modifiers].
  int get modifierMask =>
      modifiers.fold(0, (mask, modifier) => mask | modifier.win32Mask);

  /// Whether the binding claims a bare key with no modifier held.
  ///
  /// Such a binding still registers, but it takes the key away from every
  /// other application, so settings warns about it.
  bool get isBareKey => modifiers.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlobalHotkeyBinding &&
        other.virtualKeyCode == virtualKeyCode &&
        _listEquals(other.modifiers, modifiers) &&
        _listEquals(other.displayTokens, displayTokens);
  }

  @override
  int get hashCode => Object.hash(
    virtualKeyCode,
    Object.hashAll(modifiers),
    Object.hashAll(displayTokens),
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      _virtualKeyCodeKey: virtualKeyCode,
      _modifiersKey: modifiers
          .map((modifier) => modifier.storageValue)
          .toList(growable: false),
      _displayTokensKey: displayTokens,
    };
  }

  static GlobalHotkeyBinding? fromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }

    final virtualKeyCode = json[_virtualKeyCodeKey];
    final modifiersJson = json[_modifiersKey];
    final displayTokensJson = json[_displayTokensKey];
    if (virtualKeyCode is! int ||
        modifiersJson is! List ||
        displayTokensJson is! List) {
      return null;
    }

    final modifiers = <GlobalHotkeyModifier>[];
    for (final modifierJson in modifiersJson) {
      if (modifierJson is! String) {
        return null;
      }
      final modifier = GlobalHotkeyModifier.fromStorageValue(modifierJson);
      if (modifier == null) {
        return null;
      }
      modifiers.add(modifier);
    }

    final displayTokens = displayTokensJson.whereType<String>().toList();
    if (displayTokens.isEmpty) {
      return null;
    }

    return GlobalHotkeyBinding(
      virtualKeyCode: virtualKeyCode,
      modifiers: List.unmodifiable(modifiers),
      displayTokens: List.unmodifiable(displayTokens),
    );
  }

  /// Builds a binding from a recorded key press.
  ///
  /// Returns `null` when [logicalKey] cannot be registered as the primary key
  /// of a system-wide hotkey, which covers bare modifier presses and keys with
  /// no virtual-key equivalent. Callers keep recording in that case.
  static GlobalHotkeyBinding? fromKeyDown({
    required LogicalKeyboardKey logicalKey,
    required Set<LogicalKeyboardKey> pressedKeys,
  }) {
    final virtualKeyCode = virtualKeyCodeFor(logicalKey);
    if (virtualKeyCode == null) {
      return null;
    }

    final modifiers = GlobalHotkeyModifier.values
        .where((modifier) => _modifierPressed(modifier, pressedKeys))
        .toList(growable: false);

    return GlobalHotkeyBinding(
      virtualKeyCode: virtualKeyCode,
      modifiers: List.unmodifiable(modifiers),
      displayTokens: List.unmodifiable(<String>[
        for (final modifier in modifiers) modifier.displayToken,
        displayTokenFor(logicalKey),
      ]),
    );
  }

  /// Maps a [LogicalKeyboardKey] onto its platform virtual-key code.
  ///
  /// Modifier keys map to `null`: a system-wide hotkey needs a non-modifier
  /// primary key, so a bare `Ctrl` press is not a valid binding.
  static int? virtualKeyCodeFor(LogicalKeyboardKey key) {
    final mapped = _virtualKeyCodes[key];
    if (mapped != null) {
      return mapped;
    }

    // Letters and digits are laid out contiguously in both the Unicode and the
    // virtual-key ranges, so unmapped alphanumeric keys resolve by character.
    final keyLabel = key.keyLabel;
    if (keyLabel.length == 1) {
      final codeUnit = keyLabel.toUpperCase().codeUnitAt(0);
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isLetter = codeUnit >= 0x41 && codeUnit <= 0x5A;
      if (isDigit || isLetter) {
        return codeUnit;
      }
    }

    return null;
  }

  /// Label shown for [key] on a keycap.
  static String displayTokenFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) {
      return 'Space';
    }

    final keyLabel = key.keyLabel.trim();
    if (keyLabel.isNotEmpty) {
      return keyLabel.length == 1 ? keyLabel.toUpperCase() : keyLabel;
    }

    return key.debugName ?? 'Key ${key.keyId}';
  }

  static bool _modifierPressed(
    GlobalHotkeyModifier modifier,
    Set<LogicalKeyboardKey> pressedKeys,
  ) {
    return switch (modifier) {
      GlobalHotkeyModifier.alt =>
        pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.altRight),
      GlobalHotkeyModifier.control =>
        pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.controlRight),
      GlobalHotkeyModifier.shift =>
        pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.shiftRight),
      GlobalHotkeyModifier.meta =>
        pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.metaRight),
    };
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  /// Virtual-key codes for keys whose label does not resolve on its own.
  ///
  /// Values follow the Win32 `VK_*` constants.
  static final Map<LogicalKeyboardKey, int> _virtualKeyCodes = {
    LogicalKeyboardKey.backspace: 0x08,
    LogicalKeyboardKey.tab: 0x09,
    LogicalKeyboardKey.pause: 0x13,
    LogicalKeyboardKey.capsLock: 0x14,
    LogicalKeyboardKey.escape: 0x1B,
    LogicalKeyboardKey.space: 0x20,
    LogicalKeyboardKey.pageUp: 0x21,
    LogicalKeyboardKey.pageDown: 0x22,
    LogicalKeyboardKey.end: 0x23,
    LogicalKeyboardKey.home: 0x24,
    LogicalKeyboardKey.arrowLeft: 0x25,
    LogicalKeyboardKey.arrowUp: 0x26,
    LogicalKeyboardKey.arrowRight: 0x27,
    LogicalKeyboardKey.arrowDown: 0x28,
    LogicalKeyboardKey.printScreen: 0x2C,
    LogicalKeyboardKey.insert: 0x2D,
    LogicalKeyboardKey.delete: 0x2E,
    LogicalKeyboardKey.enter: 0x0D,
    LogicalKeyboardKey.numpadEnter: 0x0D,
    LogicalKeyboardKey.contextMenu: 0x5D,
    LogicalKeyboardKey.numpad0: 0x60,
    LogicalKeyboardKey.numpad1: 0x61,
    LogicalKeyboardKey.numpad2: 0x62,
    LogicalKeyboardKey.numpad3: 0x63,
    LogicalKeyboardKey.numpad4: 0x64,
    LogicalKeyboardKey.numpad5: 0x65,
    LogicalKeyboardKey.numpad6: 0x66,
    LogicalKeyboardKey.numpad7: 0x67,
    LogicalKeyboardKey.numpad8: 0x68,
    LogicalKeyboardKey.numpad9: 0x69,
    LogicalKeyboardKey.numpadMultiply: 0x6A,
    LogicalKeyboardKey.numpadAdd: 0x6B,
    LogicalKeyboardKey.numpadComma: 0x6C,
    LogicalKeyboardKey.numpadSubtract: 0x6D,
    LogicalKeyboardKey.numpadDecimal: 0x6E,
    LogicalKeyboardKey.numpadDivide: 0x6F,
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
    LogicalKeyboardKey.numLock: 0x90,
    LogicalKeyboardKey.scrollLock: 0x91,
    LogicalKeyboardKey.semicolon: 0xBA,
    LogicalKeyboardKey.colon: 0xBA,
    LogicalKeyboardKey.equal: 0xBB,
    LogicalKeyboardKey.add: 0xBB,
    LogicalKeyboardKey.comma: 0xBC,
    LogicalKeyboardKey.minus: 0xBD,
    LogicalKeyboardKey.period: 0xBE,
    LogicalKeyboardKey.slash: 0xBF,
    LogicalKeyboardKey.backquote: 0xC0,
    LogicalKeyboardKey.bracketLeft: 0xDB,
    LogicalKeyboardKey.backslash: 0xDC,
    LogicalKeyboardKey.bracketRight: 0xDD,
    LogicalKeyboardKey.quoteSingle: 0xDE,
  };
}
