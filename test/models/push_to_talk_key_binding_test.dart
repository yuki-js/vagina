import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';

void main() {
  group('PushToTalkKeyBinding', () {
    test('records a single Space key', () {
      final binding = PushToTalkKeyBinding.fromPressedKeys({
        LogicalKeyboardKey.space,
      });

      expect(binding, isNotNull);
      expect(binding!.primaryLogicalKeyId, LogicalKeyboardKey.space.keyId);
      expect(binding.modifiers, isEmpty);
      expect(binding.displayTokens, ['Space']);
    });

    test('records a single letter key as a keycap token', () {
      final binding = PushToTalkKeyBinding.fromPressedKeys({
        LogicalKeyboardKey.keyV,
      });

      expect(binding, isNotNull);
      expect(binding!.primaryLogicalKeyId, LogicalKeyboardKey.keyV.keyId);
      expect(binding.modifiers, isEmpty);
      expect(binding.displayTokens, ['V']);
    });

    test('records a modifier plus primary key combination', () {
      final binding = PushToTalkKeyBinding.fromPressedKeys({
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.space,
      });

      expect(binding, isNotNull);
      expect(binding!.primaryLogicalKeyId, LogicalKeyboardKey.space.keyId);
      expect(binding.modifiers, [PushToTalkKeyModifier.control]);
      expect(binding.displayTokens, ['Ctrl', 'Space']);
    });

    test('records a right control modifier key by itself', () {
      final binding = PushToTalkKeyBinding.fromPressedKeys({
        LogicalKeyboardKey.controlRight,
      });

      expect(binding, isNotNull);
      expect(
        binding!.primaryLogicalKeyId,
        LogicalKeyboardKey.controlRight.keyId,
      );
      expect(binding.modifiers, isEmpty);
      expect(binding.displayTokens, ['Right Ctrl']);
    });

    test('matches when primary and modifiers are pressed', () {
      final binding = PushToTalkKeyBinding(
        primaryLogicalKeyId: LogicalKeyboardKey.keyV.keyId,
        modifiers: const [PushToTalkKeyModifier.shift],
        displayTokens: const ['Shift', 'V'],
      );

      expect(
        binding.matchesPressedKeys({
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.keyV,
        }),
        isTrue,
      );
      expect(binding.matchesPressedKeys({LogicalKeyboardKey.keyV}), isFalse);
    });

    test('round-trips through json', () {
      final binding = PushToTalkKeyBinding(
        primaryLogicalKeyId: LogicalKeyboardKey.space.keyId,
        modifiers: const [
          PushToTalkKeyModifier.control,
          PushToTalkKeyModifier.shift,
        ],
        displayTokens: const ['Ctrl', 'Shift', 'Space'],
      );

      expect(PushToTalkKeyBinding.fromJson(binding.toJson()), binding);
    });
  });
}
