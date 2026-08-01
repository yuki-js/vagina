import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

/// Merges the two keyboard routes that can hold push-to-talk — the in-window
/// [HardwareKeyboard] handler and the platform global hotkey — into a single
/// held/not-held signal.
///
/// The two routes are mutually exclusive in practice: the global hook stays
/// silent while VAGINA is in the foreground, and the in-window handler only
/// sees events while VAGINA has focus. They are combined with OR anyway, so an
/// overlap during a focus change cannot drop or double a transition.
///
/// The pointer route (holding the on-screen button) is deliberately not part of
/// this. It never leaves the widget that owns the button, so routing it through
/// here would buy nothing.
class PushToTalkKeySource {
  PushToTalkKeySource({GlobalHotkeyService? globalHotkeyService})
    : _globalHotkeyService =
          globalHotkeyService ?? createGlobalHotkeyService() {
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    _globalSubscription = _globalHotkeyService.transitions.listen((transition) {
      // Gated like the in-window route. Disabling flips _enabled synchronously
      // but only uninstalls the hook on the async chain, so an event already in
      // flight can still land here and must not re-arm the hold.
      if (!_enabled || _binding == null) {
        _setGlobalHeld(false);
        return;
      }
      _setGlobalHeld(transition == GlobalHotkeyTransition.down);
    });
  }

  final GlobalHotkeyService _globalHotkeyService;

  final StreamController<bool> _heldController =
      StreamController<bool>.broadcast();

  StreamSubscription<GlobalHotkeyTransition>? _globalSubscription;

  PushToTalkKeyBinding? _binding;
  bool _enabled = false;
  bool _inWindowHeld = false;
  bool _globalHeld = false;
  bool _held = false;
  bool _disposed = false;

  /// Serialises the platform round trips so an older sync cannot overwrite the
  /// desired state of a newer one. Teardown joins the same chain.
  Future<void> _sync = Future<void>.value();

  /// Emits whenever the merged held state changes. Never emits repeats.
  Stream<bool> get heldUpdates => _heldController.stream;

  /// Whether either keyboard route is currently holding push-to-talk.
  bool get isHeld => _held;

  /// Sets the binding both routes match against. Null disables both.
  Future<void> setBinding(PushToTalkKeyBinding? binding) {
    _binding = binding;
    return _schedule();
  }

  /// Whether this source should listen at all — push-to-talk mode is on and a
  /// call is live.
  Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    return _schedule();
  }

  Future<void> dispose() {
    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _globalSubscription?.cancel();
    _globalSubscription = null;
    _sync = _sync.then((_) => _teardown()).catchError((_) {});
    final pending = _sync;
    unawaited(_heldController.close());
    return pending;
  }

  // ---------------------------------------------------------------------------
  // Merged state
  // ---------------------------------------------------------------------------

  void _setInWindowHeld(bool value) {
    if (_inWindowHeld == value) return;
    _inWindowHeld = value;
    _refreshHeld();
  }

  void _setGlobalHeld(bool value) {
    if (_globalHeld == value) return;
    _globalHeld = value;
    _refreshHeld();
  }

  void _refreshHeld() {
    final held = _inWindowHeld || _globalHeld;
    if (_held == held) return;
    _held = held;
    if (!_heldController.isClosed) {
      _heldController.add(held);
    }
  }

  /// Drops any hold that is still outstanding. Used when the source is turned
  /// off or rebound so a held key cannot leave the merged state stuck on.
  void _releaseAll() {
    _inWindowHeld = false;
    _globalHeld = false;
    _refreshHeld();
  }

  // ---------------------------------------------------------------------------
  // In-window route
  // ---------------------------------------------------------------------------

  bool _handleHardwareKeyEvent(KeyEvent event) {
    final binding = _binding;
    if (binding == null || !_enabled || _isEditableFocusActive) {
      if (_inWindowHeld && event is KeyUpEvent) {
        _setInWindowHeld(false);
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
      _setInWindowHeld(true);
      return true;
    }

    if (event is KeyUpEvent && _inWindowHeld) {
      if (!binding.matchesPressedKeys(pressed)) {
        _setInWindowHeld(false);
        return true;
      }
    }

    return false;
  }

  /// Whether a text field currently has focus. The in-window route stands down
  /// in that case so the binding stays typable; the global route has no
  /// equivalent concern because it only fires while another app has focus.
  bool get _isEditableFocusActive {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  // ---------------------------------------------------------------------------
  // Global route
  // ---------------------------------------------------------------------------

  Future<void> _schedule() {
    final scheduled = _sync.then((_) => _applyGlobalState());
    _sync = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> _applyGlobalState() async {
    if (_disposed) return;

    final binding = _binding;

    // Turning the source off, or clearing the binding, stands both routes down.
    // A platform that merely cannot host the hook is a different case: the
    // in-window route keeps working there, so only the global half is dropped.
    if (!_enabled || binding == null) {
      _releaseAll();
      await _globalHotkeyService.setActive(false);
      return;
    }

    if (!_globalHotkeyService.supportsBinding(binding)) {
      _setGlobalHeld(false);
      await _globalHotkeyService.setActive(false);
      return;
    }

    await _globalHotkeyService.setBinding(binding);
    // dispose() may have run during the platform round trip.
    if (_disposed) return;
    await _globalHotkeyService.setActive(true);
  }

  Future<void> _teardown() async {
    await _globalHotkeyService.setActive(false);
    await _globalHotkeyService.dispose();
  }
}
