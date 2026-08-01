import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/push_to_talk_input_service.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';
import 'package:vagina/services/platform/windows_virtual_key_codes.dart';

/// Stands in for the platform hook.
///
/// [supported] models a platform that cannot host a hook at all; [installs]
/// models one that can, but where SetWindowsHookEx fails.
class _FakeGlobalHotkeyService implements GlobalHotkeyService {
  _FakeGlobalHotkeyService({this.supported = true, this.installs = true});

  final bool supported;
  final bool installs;

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
    if (value && !installs) {
      return false;
    }
    active = value;
    return true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

PushToTalkKeyBinding _binding(LogicalKeyboardKey key) =>
    PushToTalkKeyBinding.fromPressedKeys(<LogicalKeyboardKey>[key])!;

/// Feeds a key event the way the engine does, so a registered handler sees it.
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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = LogicalKeyboardKey.f13;

  late _FakeGlobalHotkeyService hotkey;
  late PushToTalkInputService service;
  late List<bool> emitted;
  late StreamSubscription<bool> subscription;

  Future<void> start({bool supported = true, bool installs = true}) async {
    hotkey = _FakeGlobalHotkeyService(supported: supported, installs: installs);
    service = PushToTalkInputService(globalHotkeyService: hotkey);
    emitted = <bool>[];
    subscription = service.activeUpdates.listen(emitted.add);
    await service.configure(binding: _binding(key), enabled: true);
  }

  tearDown(() async {
    await subscription.cancel();
    await service.dispose();
    // A test that leaves a key down would otherwise leak into the next one.
    HardwareKeyboard.instance.clearState();
  });

  group('one key route at a time', () {
    test(
      'the hook drives the signal and the in-window route stays out',
      () async {
        await start();
        expect(hotkey.active, isTrue);

        hotkey.emit(GlobalHotkeyTransition.down);
        await _settle();
        expect(service.isActive, isTrue);

        hotkey.emit(GlobalHotkeyTransition.up);
        await _settle();
        expect(service.isActive, isFalse);
        expect(emitted, <bool>[true, false]);

        // The hook already reports events that arrive while VAGINA has focus, so
        // the in-window handler must not be listening as well.
        emitted.clear();
        await _sendKey(_down(key));
        expect(emitted, isEmpty);
        expect(service.isActive, isFalse);
      },
    );

    test(
      'without hook support the in-window route drives the signal',
      () async {
        await start(supported: false);
        expect(hotkey.active, isFalse);
        expect(hotkey.lastBinding, isNull);

        await _sendKey(_down(key));
        expect(service.isActive, isTrue);

        await _sendKey(_up(key));
        expect(service.isActive, isFalse);
        expect(emitted, <bool>[true, false]);
      },
    );

    test(
      'a hook that fails to install falls back instead of going dead',
      () async {
        await start(installs: false);
        expect(hotkey.active, isFalse);

        await _sendKey(_down(key));
        expect(service.isActive, isTrue);

        await _sendKey(_up(key));
        expect(emitted, <bool>[true, false]);
      },
    );
  });

  group('merging the key and the button', () {
    test('either input alone drives the signal', () async {
      await start(supported: false);

      service.setPointerActive(true);
      expect(service.isActive, isTrue);
      service.setPointerActive(false);
      expect(service.isActive, isFalse);

      await _sendKey(_down(key));
      expect(service.isActive, isTrue);
      await _sendKey(_up(key));

      expect(emitted, <bool>[true, false, true, false]);
    });

    test('overlapping inputs emit one transition, not two', () async {
      await start(supported: false);

      await _sendKey(_down(key));
      service.setPointerActive(true);
      expect(emitted, <bool>[true]);

      // Still held while either input holds it.
      await _sendKey(_up(key));
      expect(service.isActive, isTrue);
      expect(emitted, <bool>[true]);

      service.setPointerActive(false);
      await _settle();
      expect(emitted, <bool>[true, false]);
    });

    test('the hook repeating down does not re-emit', () async {
      await start();

      hotkey.emit(GlobalHotkeyTransition.down);
      hotkey.emit(GlobalHotkeyTransition.down);
      await _settle();

      expect(emitted, <bool>[true]);
    });
  });

  group('standing down', () {
    test('disabling releases both inputs', () async {
      await start();

      hotkey.emit(GlobalHotkeyTransition.down);
      await _settle();
      service.setPointerActive(true);
      expect(service.isActive, isTrue);

      await service.configure(binding: _binding(key), enabled: false);
      expect(service.isActive, isFalse);
      expect(emitted, <bool>[true, false]);
      expect(hotkey.active, isFalse);
    });

    test('clearing the binding releases and unhooks', () async {
      await start();
      hotkey.emit(GlobalHotkeyTransition.down);
      await _settle();

      await service.configure(binding: null, enabled: true);
      expect(service.isActive, isFalse);
      expect(hotkey.active, isFalse);
    });

    test('a disabled service ignores every input', () async {
      await start();
      await service.configure(binding: _binding(key), enabled: false);
      emitted.clear();

      // The hook is uninstalled while disabled, so an event already in flight
      // is the only way this arrives — it must not re-arm the signal.
      hotkey.emit(GlobalHotkeyTransition.down);
      await _settle();
      service.setPointerActive(true);
      await _sendKey(_down(key));

      expect(emitted, isEmpty);
      expect(service.isActive, isFalse);
    });

    test('dispose unhooks and releases the platform service', () async {
      await start();
      await service.dispose();

      expect(hotkey.active, isFalse);
      expect(hotkey.disposed, isTrue);
    });
  });

  group('binding semantics shared with the native matcher', () {
    test('a modifier-only binding survives the VK conversion', () {
      // The native side has to represent this, otherwise a modifier-only
      // push-to-talk silently never fires.
      expect(
        windowsGlobalHotkeyPayloadForBinding(
          _binding(LogicalKeyboardKey.controlRight),
        ),
        isNotNull,
      );
    });

    test('extra modifiers do not suppress a match on either side', () {
      final binding = _binding(key);

      // Dart side: requirements are a subset of what is held.
      expect(
        binding.matchesPressedKeys(<LogicalKeyboardKey>{
          key,
          LogicalKeyboardKey.shiftLeft,
        }),
        isTrue,
      );

      // Native side: a binding with no modifier requirements asks for none, so
      // the hook never inspects the ones the user happens to hold.
      final payload = windowsGlobalHotkeyPayloadForBinding(binding)!;
      expect(payload['requiresControl'], isFalse);
      expect(payload['requiresShift'], isFalse);
      expect(payload['requiresAlt'], isFalse);
      expect(payload['requiresMeta'], isFalse);
    });
  });
}
