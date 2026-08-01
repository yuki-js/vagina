import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

/// Collects every way push-to-talk can be held — the configured key and the
/// on-screen button — into a single active/not-active signal.
///
/// Exactly one keyboard route is ever live. Where the platform can host a
/// global hook that hook sees every key event, including the ones that arrive
/// while VAGINA has focus, so the in-window handler would only ever repeat what
/// the hook already reported. The in-window handler is the fallback for
/// platforms without a hook, and for a hook that fails to install.
///
/// Shaped like [RecorderService]'s mute state: a current value, a stream of
/// changes, and a plain setter for the input this service cannot read itself.
class PushToTalkInputService {
  PushToTalkInputService({GlobalHotkeyService? globalHotkeyService})
    : _globalHotkeyService = globalHotkeyService ?? createGlobalHotkeyService();

  final GlobalHotkeyService _globalHotkeyService;

  final StreamController<bool> _activeController =
      StreamController<bool>.broadcast();

  StreamSubscription<GlobalHotkeyTransition>? _hookSubscription;
  bool _inWindowHandlerRegistered = false;

  PushToTalkKeyBinding? _binding;
  bool _enabled = false;
  bool _keyActive = false;
  bool _pointerActive = false;
  bool _active = false;
  bool _disposed = false;

  /// Serialises the platform round trips so an older configure cannot overwrite
  /// the intent of a newer one. Teardown joins the same chain.
  Future<void> _sync = Future<void>.value();

  /// Whether push-to-talk is being held right now, by any input.
  bool get isActive => _active;

  /// Emits whenever [isActive] changes. Never emits repeats.
  Stream<bool> get activeUpdates => _activeController.stream;

  /// Reports the on-screen button's state. The only input this service cannot
  /// observe for itself.
  void setPointerActive(bool active) {
    if (!_enabled) {
      active = false;
    }
    if (_pointerActive == active) {
      return;
    }
    _pointerActive = active;
    _refresh();
  }

  /// Points the service at the current intent. [enabled] means push-to-talk
  /// mode is on and a call is live.
  Future<void> configure({
    required PushToTalkKeyBinding? binding,
    required bool enabled,
  }) {
    _binding = binding;
    _enabled = enabled;
    if (!enabled || binding == null) {
      // Drop any outstanding hold synchronously, so a key that is still down
      // cannot leave the signal stuck on while the teardown runs.
      _keyActive = false;
      _pointerActive = false;
      _refresh();
    }
    final scheduled = _sync.then((_) => _applyKeySource());
    _sync = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> dispose() {
    _disposed = true;
    _unregisterInWindowHandler();
    _hookSubscription?.cancel();
    _hookSubscription = null;
    _sync = _sync.then((_) => _teardown()).catchError((_) {});
    final pending = _sync;
    unawaited(_activeController.close());
    return pending;
  }

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  void _setKeyActive(bool active) {
    if (_keyActive == active) {
      return;
    }
    _keyActive = active;
    _refresh();
  }

  void _refresh() {
    final active = _keyActive || _pointerActive;
    if (_active == active) {
      return;
    }
    _active = active;
    if (!_activeController.isClosed) {
      _activeController.add(active);
    }
  }

  // ---------------------------------------------------------------------------
  // Key source selection
  // ---------------------------------------------------------------------------

  Future<void> _applyKeySource() async {
    if (_disposed) {
      return;
    }

    final binding = _binding;
    if (!_enabled || binding == null) {
      _unregisterInWindowHandler();
      await _detachHook();
      return;
    }

    if (_globalHotkeyService.supportsBinding(binding)) {
      // The hook covers every case the in-window handler would, so the two are
      // never live at once.
      _unregisterInWindowHandler();
      if (await _attachHook(binding)) {
        return;
      }
      // Installing the hook failed. Fall back rather than leaving the key dead.
      await _detachHook();
    }

    _registerInWindowHandler();
  }

  Future<bool> _attachHook(PushToTalkKeyBinding binding) async {
    await _globalHotkeyService.setBinding(binding);
    if (_disposed) {
      return true;
    }
    if (!await _globalHotkeyService.setActive(true)) {
      return false;
    }
    _hookSubscription ??= _globalHotkeyService.transitions.listen((transition) {
      // configure() drops _enabled synchronously but only uninstalls the hook
      // on the async chain, so an event already in flight can still land here.
      if (!_enabled || _binding == null) {
        _setKeyActive(false);
        return;
      }
      _setKeyActive(transition == GlobalHotkeyTransition.down);
    });
    return true;
  }

  Future<void> _detachHook() async {
    await _hookSubscription?.cancel();
    _hookSubscription = null;
    _setKeyActive(false);
    await _globalHotkeyService.setActive(false);
  }

  // ---------------------------------------------------------------------------
  // In-window fallback
  // ---------------------------------------------------------------------------

  void _registerInWindowHandler() {
    if (_inWindowHandlerRegistered) {
      return;
    }
    _inWindowHandlerRegistered = true;
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
  }

  void _unregisterInWindowHandler() {
    if (!_inWindowHandlerRegistered) {
      return;
    }
    _inWindowHandlerRegistered = false;
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _setKeyActive(false);
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    final binding = _binding;
    if (binding == null || !_enabled) {
      if (_keyActive && event is KeyUpEvent) {
        _setKeyActive(false);
      }
      return false;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    if (event is KeyRepeatEvent) {
      return binding.matchesPressedKeys(pressed);
    }

    if (event is KeyDownEvent) {
      if (!binding.matchesPressedKeys(pressed)) {
        return false;
      }
      _setKeyActive(true);
      return true;
    }

    if (event is KeyUpEvent && _keyActive) {
      if (!binding.matchesPressedKeys(pressed)) {
        _setKeyActive(false);
        return true;
      }
    }

    return false;
  }

  Future<void> _teardown() async {
    await _globalHotkeyService.setActive(false);
    await _globalHotkeyService.dispose();
  }
}
