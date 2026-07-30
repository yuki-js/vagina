import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/global_hotkey_binding.dart';

void main() {
  group('GlobalHotkeyBinding.fromKeyDown', () {
    test('records a letter key without modifiers', () {
      final binding = GlobalHotkeyBinding.fromKeyDown(
        logicalKey: LogicalKeyboardKey.keyV,
        pressedKeys: {LogicalKeyboardKey.keyV},
      );

      expect(binding, isNotNull);
      expect(binding!.virtualKeyCode, 0x56);
      expect(binding.modifiers, isEmpty);
      expect(binding.displayTokens, ['V']);
      expect(binding.isBareKey, isTrue);
    });

    test('records modifiers in display order', () {
      final binding = GlobalHotkeyBinding.fromKeyDown(
        logicalKey: LogicalKeyboardKey.space,
        pressedKeys: {
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.shiftRight,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.space,
        },
      );

      expect(binding, isNotNull);
      expect(binding!.virtualKeyCode, 0x20);
      expect(binding.modifiers, [
        GlobalHotkeyModifier.control,
        GlobalHotkeyModifier.shift,
        GlobalHotkeyModifier.alt,
      ]);
      expect(binding.displayTokens, ['Ctrl', 'Shift', 'Alt', 'Space']);
      expect(binding.isBareKey, isFalse);
    });

    test('combines the Win32 modifier mask', () {
      final binding = GlobalHotkeyBinding.fromKeyDown(
        logicalKey: LogicalKeyboardKey.f9,
        pressedKeys: {
          LogicalKeyboardKey.controlRight,
          LogicalKeyboardKey.metaLeft,
          LogicalKeyboardKey.f9,
        },
      );

      expect(binding, isNotNull);
      expect(binding!.virtualKeyCode, 0x78);
      // MOD_CONTROL | MOD_WIN
      expect(binding.modifierMask, 0x0002 | 0x0008);
    });

    test('rejects a bare modifier press', () {
      final binding = GlobalHotkeyBinding.fromKeyDown(
        logicalKey: LogicalKeyboardKey.controlLeft,
        pressedKeys: {LogicalKeyboardKey.controlLeft},
      );

      expect(binding, isNull);
    });

    test('rejects a key with no virtual-key equivalent', () {
      final binding = GlobalHotkeyBinding.fromKeyDown(
        logicalKey: LogicalKeyboardKey.gameButtonA,
        pressedKeys: {LogicalKeyboardKey.gameButtonA},
      );

      expect(binding, isNull);
    });
  });

  group('GlobalHotkeyBinding.virtualKeyCodeFor', () {
    test('resolves digits and letters by character', () {
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.digit1),
        0x31,
      );
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.keyA),
        0x41,
      );
    });

    test('maps the numpad separately from the digit row', () {
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.numpad1),
        0x61,
      );
    });

    test('maps keys whose label is not a single character', () {
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.escape),
        0x1B,
      );
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.arrowDown),
        0x28,
      );
      expect(
        GlobalHotkeyBinding.virtualKeyCodeFor(LogicalKeyboardKey.f24),
        0x87,
      );
    });
  });

  group('GlobalHotkeyBinding serialization', () {
    test('round-trips through JSON', () {
      const binding = GlobalHotkeyBinding(
        virtualKeyCode: 0x20,
        modifiers: [GlobalHotkeyModifier.control, GlobalHotkeyModifier.alt],
        displayTokens: ['Ctrl', 'Alt', 'Space'],
      );

      expect(GlobalHotkeyBinding.fromJson(binding.toJson()), binding);
    });

    test('rejects payloads that are not readable bindings', () {
      expect(GlobalHotkeyBinding.fromJson(null), isNull);
      expect(GlobalHotkeyBinding.fromJson('Ctrl+Space'), isNull);
      expect(
        GlobalHotkeyBinding.fromJson(<String, dynamic>{
          'virtualKeyCode': '32',
          'modifiers': <String>[],
          'displayTokens': <String>['Space'],
        }),
        isNull,
      );
      expect(
        GlobalHotkeyBinding.fromJson(<String, dynamic>{
          'virtualKeyCode': 32,
          'modifiers': <String>['hyper'],
          'displayTokens': <String>['Space'],
        }),
        isNull,
      );
      expect(
        GlobalHotkeyBinding.fromJson(<String, dynamic>{
          'virtualKeyCode': 32,
          'modifiers': <String>[],
          'displayTokens': <String>[],
        }),
        isNull,
      );
    });
  });

  group('GlobalHotkeyAction', () {
    test('round-trips through its storage value', () {
      for (final action in GlobalHotkeyAction.values) {
        expect(
          GlobalHotkeyAction.fromStorageValue(action.storageValue),
          action,
        );
      }
      expect(GlobalHotkeyAction.fromStorageValue('sendCarrierPigeon'), isNull);
    });

    test('tracks key releases only for hold-to-talk', () {
      for (final action in GlobalHotkeyAction.values) {
        expect(
          action.tracksKeyRelease,
          action == GlobalHotkeyAction.pushToTalk,
          reason: 'unexpected release tracking for ${action.name}',
        );
      }
    });
  });
}
