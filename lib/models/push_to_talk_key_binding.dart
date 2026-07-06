import 'package:flutter/services.dart';

enum PushToTalkKeyModifier {
  control,
  shift,
  alt,
  meta;

  String get storageValue => name;

  String get displayToken {
    return switch (this) {
      PushToTalkKeyModifier.control => 'Ctrl',
      PushToTalkKeyModifier.shift => 'Shift',
      PushToTalkKeyModifier.alt => 'Alt',
      PushToTalkKeyModifier.meta => 'Meta',
    };
  }

  static PushToTalkKeyModifier? fromStorageValue(String value) {
    for (final modifier in PushToTalkKeyModifier.values) {
      if (modifier.storageValue == value) {
        return modifier;
      }
    }
    return null;
  }
}

class PushToTalkKeyBinding {
  static const String _primaryLogicalKeyIdKey = 'primaryLogicalKeyId';
  static const String _modifiersKey = 'modifiers';
  static const String _displayTokensKey = 'displayTokens';

  final int primaryLogicalKeyId;
  final List<PushToTalkKeyModifier> modifiers;
  final List<String> displayTokens;

  const PushToTalkKeyBinding({
    required this.primaryLogicalKeyId,
    required this.modifiers,
    required this.displayTokens,
  });

  LogicalKeyboardKey get primaryLogicalKey =>
      LogicalKeyboardKey(primaryLogicalKeyId);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PushToTalkKeyBinding &&
        other.primaryLogicalKeyId == primaryLogicalKeyId &&
        _listEquals(other.modifiers, modifiers) &&
        _listEquals(other.displayTokens, displayTokens);
  }

  @override
  int get hashCode => Object.hash(
    primaryLogicalKeyId,
    Object.hashAll(modifiers),
    Object.hashAll(displayTokens),
  );

  bool get isModifierOnly {
    return _modifierForLogicalKey(primaryLogicalKey) != null &&
        modifiers.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      _primaryLogicalKeyIdKey: primaryLogicalKeyId,
      _modifiersKey: modifiers
          .map((modifier) => modifier.storageValue)
          .toList(),
      _displayTokensKey: displayTokens,
    };
  }

  static PushToTalkKeyBinding? fromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }

    final primaryLogicalKeyId = json[_primaryLogicalKeyIdKey];
    final modifiersJson = json[_modifiersKey];
    final displayTokensJson = json[_displayTokensKey];
    if (primaryLogicalKeyId is! int ||
        modifiersJson is! List ||
        displayTokensJson is! List) {
      return null;
    }

    final modifiers = <PushToTalkKeyModifier>[];
    for (final modifierJson in modifiersJson) {
      if (modifierJson is! String) {
        return null;
      }
      final modifier = PushToTalkKeyModifier.fromStorageValue(modifierJson);
      if (modifier == null) {
        return null;
      }
      modifiers.add(modifier);
    }

    final displayTokens = displayTokensJson.whereType<String>().toList();
    if (displayTokens.isEmpty) {
      return null;
    }

    return PushToTalkKeyBinding(
      primaryLogicalKeyId: primaryLogicalKeyId,
      modifiers: List.unmodifiable(modifiers),
      displayTokens: List.unmodifiable(displayTokens),
    );
  }

  static PushToTalkKeyBinding? fromPressedKeys(
    Iterable<LogicalKeyboardKey> pressedKeys,
  ) {
    final keys = pressedKeys.toSet();
    if (keys.isEmpty) {
      return null;
    }

    final nonModifierKeys = keys
        .where((key) => _modifierForLogicalKey(key) == null)
        .toList(growable: false);
    final primaryKey = nonModifierKeys.isNotEmpty
        ? _lastSortedKey(nonModifierKeys)
        : _lastSortedKey(keys);
    final primaryModifier = _modifierForLogicalKey(primaryKey);
    final modifiers = primaryModifier == null
        ? _pressedModifiers(keys)
        : <PushToTalkKeyModifier>[];
    final displayTokens = <String>[
      for (final modifier in modifiers) modifier.displayToken,
      _displayTokenForLogicalKey(primaryKey),
    ];

    return PushToTalkKeyBinding(
      primaryLogicalKeyId: primaryKey.keyId,
      modifiers: List.unmodifiable(modifiers),
      displayTokens: List.unmodifiable(displayTokens),
    );
  }

  bool matchesPressedKeys(Set<LogicalKeyboardKey> pressedKeys) {
    if (!pressedKeys.contains(primaryLogicalKey)) {
      return false;
    }

    for (final modifier in modifiers) {
      if (!_modifierPressed(modifier, pressedKeys)) {
        return false;
      }
    }

    return true;
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

  static LogicalKeyboardKey _lastSortedKey(Iterable<LogicalKeyboardKey> keys) {
    final sortedKeys = keys.toList()
      ..sort((left, right) => left.keyId.compareTo(right.keyId));
    return sortedKeys.last;
  }

  static List<PushToTalkKeyModifier> _pressedModifiers(
    Set<LogicalKeyboardKey> keys,
  ) {
    return PushToTalkKeyModifier.values
        .where((modifier) => _modifierPressed(modifier, keys))
        .toList(growable: false);
  }

  static bool _modifierPressed(
    PushToTalkKeyModifier modifier,
    Set<LogicalKeyboardKey> keys,
  ) {
    return switch (modifier) {
      PushToTalkKeyModifier.control =>
        keys.contains(LogicalKeyboardKey.controlLeft) ||
            keys.contains(LogicalKeyboardKey.controlRight),
      PushToTalkKeyModifier.shift =>
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
            keys.contains(LogicalKeyboardKey.shiftRight),
      PushToTalkKeyModifier.alt =>
        keys.contains(LogicalKeyboardKey.altLeft) ||
            keys.contains(LogicalKeyboardKey.altRight),
      PushToTalkKeyModifier.meta =>
        keys.contains(LogicalKeyboardKey.metaLeft) ||
            keys.contains(LogicalKeyboardKey.metaRight),
    };
  }

  static PushToTalkKeyModifier? _modifierForLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      return PushToTalkKeyModifier.control;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      return PushToTalkKeyModifier.shift;
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      return PushToTalkKeyModifier.alt;
    }
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return PushToTalkKeyModifier.meta;
    }
    return null;
  }

  static String _displayTokenForLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) {
      return 'Space';
    }
    if (key == LogicalKeyboardKey.controlLeft) {
      return 'Left Ctrl';
    }
    if (key == LogicalKeyboardKey.controlRight) {
      return 'Right Ctrl';
    }
    if (key == LogicalKeyboardKey.shiftLeft) {
      return 'Left Shift';
    }
    if (key == LogicalKeyboardKey.shiftRight) {
      return 'Right Shift';
    }
    if (key == LogicalKeyboardKey.altLeft) {
      return 'Left Alt';
    }
    if (key == LogicalKeyboardKey.altRight) {
      return 'Right Alt';
    }
    if (key == LogicalKeyboardKey.metaLeft) {
      return 'Left Meta';
    }
    if (key == LogicalKeyboardKey.metaRight) {
      return 'Right Meta';
    }

    final keyLabel = key.keyLabel.trim();
    if (keyLabel.isNotEmpty) {
      return keyLabel.length == 1 ? keyLabel.toUpperCase() : keyLabel;
    }

    return key.debugName ?? 'Key ${key.keyId}';
  }
}
