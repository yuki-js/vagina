import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/push_to_talk_key_source.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';
import 'package:vagina/services/platform/windows_virtual_key_codes.dart';

/// Stands in for the platform hook so the merge logic can be driven from the
/// test. [supported] mirrors a platform that cannot host the hook at all.
class _FakeGlobalHotkeyService implements GlobalHotkeyService {
  _FakeGlobalHotkeyService({this.supported = true});

  final bool supported;

  final StreamController<GlobalHotkeyTransition> _controller =
      StreamController<GlobalHotkeyTransition>.broadcast();

  PushToTalkKeyBinding? lastBinding;
  bool active = false;
  bool disposed = false;

  void emit(GlobalHotkeyTransition transition) => _controller.add(transition);

  @override
  bool get isSupported => supported;

  @override
  Stream<GlobalHotkeyTransition> get transitions => _controller.stream;

  @override
  Future<void> setBinding(PushToTalkKeyBinding? binding) async {
    lastBinding = binding;
  }

  @override
  bool supportsBinding(PushToTalkKeyBinding binding) => supported;

  @override
  Future<bool> setActive(bool value) async {
    active = value;
    return true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

PushToTalkKeyBinding _binding(LogicalKeyboardKey key) {
  return PushToTalkKeyBinding.fromPressedKeys(<LogicalKeyboardKey>[key])!;
}

/// Feeds a key event through the global handler chain the same way the engine
/// does, so the source's registered handler sees it.
Future<void> _sendKey(KeyEvent event) async {
  HardwareKeyboard.instance.handleKeyEvent(event);
  await Future<void>.delayed(Duration.zero);
}

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.f13,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyUpEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.f13,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = LogicalKeyboardKey.f13;

  late _FakeGlobalHotkeyService hotkey;
  late PushToTalkKeySource source;
  late List<bool> emitted;
  late StreamSubscription<bool> subscription;

  Future<void> setUpSource({bool supported = true}) async {
    hotkey = _FakeGlobalHotkeyService(supported: supported);
    source = PushToTalkKeySource(globalHotkeyService: hotkey);
    emitted = <bool>[];
    subscription = source.heldUpdates.listen(emitted.add);
    await source.setBinding(_binding(key));
    await source.setEnabled(true);
  }

  tearDown(() async {
    await subscription.cancel();
    await source.dispose();
    // A test that leaves a key down would otherwise leak into the next one.
    HardwareKeyboard.instance.clearState();
  });

  group('merging the two keyboard routes', () {
    test('the global route alone drives the held state', () async {
      await setUpSource();

      hotkey.emit(GlobalHotkeyTransition.down);
      await Future<void>.delayed(Duration.zero);
      expect(source.isHeld, isTrue);

      hotkey.emit(GlobalHotkeyTransition.up);
      await Future<void>.delayed(Duration.zero);
      expect(source.isHeld, isFalse);

      expect(emitted, <bool>[true, false]);
    });

    test('the in-window route alone drives the held state', () async {
      await setUpSource();

      await _sendKey(_down(key));
      expect(source.isHeld, isTrue);

      await _sendKey(_up(key));
      expect(source.isHeld, isFalse);

      expect(emitted, <bool>[true, false]);
    });

    test('overlapping routes emit one transition, not two', () async {
      await setUpSource();

      await _sendKey(_down(key));
      hotkey.emit(GlobalHotkeyTransition.down);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, <bool>[true]);

      // Still held while either route holds it.
      hotkey.emit(GlobalHotkeyTransition.up);
      await Future<void>.delayed(Duration.zero);
      expect(source.isHeld, isTrue);
      expect(emitted, <bool>[true]);

      await _sendKey(_up(key));
      expect(emitted, <bool>[true, false]);
    });

    test('auto-repeat does not re-emit', () async {
      await setUpSource();

      await _sendKey(_down(key));
      hotkey.emit(GlobalHotkeyTransition.down);
      hotkey.emit(GlobalHotkeyTransition.down);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, <bool>[true]);
    });
  });

  group('standing down', () {
    test('disabling releases a hold that is still outstanding', () async {
      await setUpSource();

      hotkey.emit(GlobalHotkeyTransition.down);
      await Future<void>.delayed(Duration.zero);
      expect(source.isHeld, isTrue);

      await source.setEnabled(false);
      expect(source.isHeld, isFalse);
      expect(emitted, <bool>[true, false]);
      expect(hotkey.active, isFalse);
    });

    test('clearing the binding releases a hold and unhooks', () async {
      await setUpSource();

      await _sendKey(_down(key));
      expect(source.isHeld, isTrue);

      await source.setBinding(null);
      expect(source.isHeld, isFalse);
      expect(hotkey.active, isFalse);
    });

    test('a disabled source ignores both routes', () async {
      await setUpSource();
      await source.setEnabled(false);
      emitted.clear();

      await _sendKey(_down(key));
      hotkey.emit(GlobalHotkeyTransition.down);
      await Future<void>.delayed(Duration.zero);

      // The hook is uninstalled while disabled, so a stray native event is the
      // only way this arrives — it must not resurrect the held state.
      expect(emitted, isEmpty);
      expect(source.isHeld, isFalse);
    });

    test('dispose unhooks and releases the platform service', () async {
      await setUpSource();
      await source.dispose();

      expect(hotkey.active, isFalse);
      expect(hotkey.disposed, isTrue);

      // dispose() is idempotent enough to survive the tearDown call.
    });
  });

  group('platforms without a global hook', () {
    test('the in-window route still works', () async {
      await setUpSource(supported: false);

      await _sendKey(_down(key));
      expect(source.isHeld, isTrue);

      await _sendKey(_up(key));
      expect(source.isHeld, isFalse);
      expect(emitted, <bool>[true, false]);
    });

    test('the hook is never installed', () async {
      await setUpSource(supported: false);

      expect(hotkey.active, isFalse);
      expect(hotkey.lastBinding, isNull);
    });
  });

  group('binding semantics shared with the native matcher', () {
    test('a modifier-only binding survives the VK conversion', () {
      final binding = _binding(LogicalKeyboardKey.controlRight);

      // The native side has to be able to represent this, otherwise
      // modifier-only push-to-talk silently never fires.
      expect(windowsGlobalHotkeyPayloadForBinding(binding), isNotNull);
    });

    test('extra modifiers do not suppress a match on either side', () {
      final binding = _binding(key);

      // Dart side: matchesPressedKeys treats requirements as a subset.
      expect(
        binding.matchesPressedKeys(<LogicalKeyboardKey>{
          key,
          LogicalKeyboardKey.shiftLeft,
        }),
        isTrue,
      );

      // Native side: a binding with no modifier requirements asks for none, so
      // the hook does not inspect the ones the user happens to hold.
      final payload = windowsGlobalHotkeyPayloadForBinding(binding)!;
      expect(payload['requiresControl'], isFalse);
      expect(payload['requiresShift'], isFalse);
      expect(payload['requiresAlt'], isFalse);
      expect(payload['requiresMeta'], isFalse);
    });
  });
}
