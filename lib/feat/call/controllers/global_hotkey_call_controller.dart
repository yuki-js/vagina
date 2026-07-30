import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

/// Turns system-wide hotkey events into call actions.
///
/// Hold-to-talk and the start/send toggle drive one shared input turn: whichever
/// hotkey started the turn, either can end it, and no hotkey starts a second
/// turn on top of a running one.
class GlobalHotkeyCallController {
  final bool Function() _isPushToTalkMode;
  final void Function() _onInputStart;
  final void Function() _onInputSend;
  final void Function() _onInputCancel;
  final void Function() _onInterrupt;
  final void Function() _onMuteToggle;

  bool _isInputActive = false;

  GlobalHotkeyCallController({
    required bool Function() isPushToTalkMode,
    required void Function() onInputStart,
    required void Function() onInputSend,
    required void Function() onInputCancel,
    required void Function() onInterrupt,
    required void Function() onMuteToggle,
  }) : _isPushToTalkMode = isPushToTalkMode,
       _onInputStart = onInputStart,
       _onInputSend = onInputSend,
       _onInputCancel = onInputCancel,
       _onInterrupt = onInterrupt,
       _onMuteToggle = onMuteToggle;

  /// Whether a hotkey-driven input turn is running.
  bool get isInputActive => _isInputActive;

  void handle(GlobalHotkeyEvent event) {
    // Hold-to-talk is the only action that means something on release.
    if (!event.isPressed && event.action != GlobalHotkeyAction.pushToTalk) {
      return;
    }

    switch (event.action) {
      case GlobalHotkeyAction.pushToTalk:
        if (event.isPressed) {
          _startInput();
        } else {
          _sendInput();
        }
      case GlobalHotkeyAction.pushToTalkToggle:
        if (_isInputActive) {
          _sendInput();
        } else {
          _startInput();
        }
      case GlobalHotkeyAction.cancelInput:
        _cancelInput();
      case GlobalHotkeyAction.interrupt:
        _onInterrupt();
      case GlobalHotkeyAction.muteToggle:
        _onMuteToggle();
    }
  }

  /// Forgets a running input turn without sending or discarding it.
  ///
  /// Used when the call leaves push-to-talk mode, where the call service has
  /// already dropped the turn.
  void reset() {
    _isInputActive = false;
  }

  /// Input turns only exist in push-to-talk mode; in hands-free mode the
  /// microphone is already open, so there is nothing to start.
  void _startInput() {
    if (_isInputActive || !_isPushToTalkMode()) {
      return;
    }

    _isInputActive = true;
    _onInputStart();
  }

  void _sendInput() {
    if (!_isInputActive) {
      return;
    }

    _isInputActive = false;
    _onInputSend();
  }

  /// Discarding reaches the call even with no hotkey-driven turn running, so it
  /// also clears a turn started from the in-app push-to-talk key.
  void _cancelInput() {
    _isInputActive = false;
    _onInputCancel();
  }
}
