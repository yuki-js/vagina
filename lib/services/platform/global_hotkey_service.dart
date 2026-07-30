import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/utils/platform_compat.dart';

/// A press or a release of a system-wide hotkey.
class GlobalHotkeyEvent {
  final GlobalHotkeyAction action;

  /// `true` for a press, `false` for a release.
  ///
  /// Releases are only reported for actions with
  /// [GlobalHotkeyAction.tracksKeyRelease].
  final bool isPressed;

  const GlobalHotkeyEvent({required this.action, required this.isPressed});
}

/// Registers system-wide hotkeys with the host OS.
///
/// System-wide hotkeys keep working while another application owns keyboard
/// focus, which is what lets a call be driven without switching windows. The
/// platform side registers only the requested combinations, so keystrokes aimed
/// at other applications are never delivered to this app.
///
/// A single instance owns the platform channel: constructing a second instance
/// takes over event delivery from the first. Register the hotkeys for as long as
/// they are needed and [dispose] the service afterwards so the combinations go
/// back to the rest of the system.
class GlobalHotkeyService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'app.aoki.yuki.vagina/global_hotkeys',
  );
  static final Logger _logger = Logger('GlobalHotkeyService');

  final MethodChannel _channel;
  final bool _isSupported;
  final StreamController<GlobalHotkeyEvent> _eventController =
      StreamController<GlobalHotkeyEvent>.broadcast();

  bool _disposed = false;

  GlobalHotkeyService({MethodChannel? channel, bool? isSupported})
    : _channel = channel ?? _defaultChannel,
      _isSupported = isSupported ?? isSupportedPlatform {
    if (_isSupported) {
      _channel.setMethodCallHandler(_handlePlatformCall);
    }
  }

  /// Whether the running platform can register system-wide hotkeys.
  ///
  /// Windows registers them through the OS hotkey table. The other platforms
  /// have no equivalent contract yet, so their settings hide the feature.
  static bool get isSupportedPlatform => PlatformCompat.isWindows;

  /// Whether this service can register system-wide hotkeys.
  bool get isSupported => _isSupported;

  /// Presses and releases of the currently applied hotkeys.
  Stream<GlobalHotkeyEvent> get events => _eventController.stream;

  /// Registers [bindings], replacing every previously applied hotkey.
  ///
  /// Returns the actions the OS refused. A refusal means another application
  /// already owns that combination, so the binding is inactive and the user has
  /// to pick a different key.
  Future<Set<GlobalHotkeyAction>> apply(
    Map<GlobalHotkeyAction, GlobalHotkeyBinding> bindings,
  ) async {
    if (!_isSupported || _disposed) {
      return bindings.keys.toSet();
    }

    if (bindings.isEmpty) {
      await clear();
      return const <GlobalHotkeyAction>{};
    }

    final payload = <Map<String, dynamic>>[
      for (final entry in bindings.entries)
        <String, dynamic>{
          'id': entry.key.storageValue,
          'virtualKeyCode': entry.value.virtualKeyCode,
          'modifiers': entry.value.modifierMask,
          'tracksRelease': entry.key.tracksKeyRelease,
        },
    ];

    try {
      final rejectedIds = await _channel.invokeListMethod<String>(
        'setHotkeys',
        payload,
      );
      return _actionsFromIds(rejectedIds ?? const <String>[]);
    } on PlatformException catch (error) {
      _logger.warning('Failed to register global hotkeys: ${error.message}');
      return bindings.keys.toSet();
    } on MissingPluginException {
      _logger.warning('Global hotkeys are unavailable on this platform build.');
      return bindings.keys.toSet();
    }
  }

  /// Releases every registered hotkey.
  Future<void> clear() async {
    if (!_isSupported || _disposed) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('clearHotkeys');
    } on PlatformException catch (error) {
      _logger.warning('Failed to release global hotkeys: ${error.message}');
    } on MissingPluginException {
      // Nothing was registered, so nothing has to be released.
    }
  }

  /// Releases the hotkeys and stops reporting events.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    await clear();
    _disposed = true;
    if (_isSupported) {
      _channel.setMethodCallHandler(null);
    }
    await _eventController.close();
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    final isPressed = switch (call.method) {
      'onHotkeyPressed' => true,
      'onHotkeyReleased' => false,
      _ => null,
    };
    if (isPressed == null) {
      return;
    }

    final argument = call.arguments;
    if (argument is! String) {
      return;
    }

    final action = GlobalHotkeyAction.fromStorageValue(argument);
    if (action == null || _eventController.isClosed) {
      return;
    }

    _eventController.add(
      GlobalHotkeyEvent(action: action, isPressed: isPressed),
    );
  }

  Set<GlobalHotkeyAction> _actionsFromIds(Iterable<String> ids) {
    final actions = <GlobalHotkeyAction>{};
    for (final id in ids) {
      final action = GlobalHotkeyAction.fromStorageValue(id);
      if (action != null) {
        actions.add(action);
      }
    }
    return actions;
  }
}
