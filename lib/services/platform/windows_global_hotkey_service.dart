import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';
import 'package:vagina/services/platform/windows_virtual_key_codes.dart';

/// Windows-specific implementation of GlobalHotkeyService.
///
/// Uses MethodChannel to communicate with native Windows code that manages
/// global hotkey registration via WH_KEYBOARD_LL hook, and EventChannel to
/// receive hotkey press/release events.
class WindowsGlobalHotkeyService implements GlobalHotkeyService {
  static const MethodChannel _methodChannel = MethodChannel(
    'app.aoki.yuki.vagina/global_hotkey',
  );

  static const EventChannel _eventChannel = EventChannel(
    'app.aoki.yuki.vagina/global_hotkey_events',
  );

  static final Logger _logger = Logger('WindowsGlobalHotkeyService');

  Stream<GlobalHotkeyTransition>? _transitionsCache;

  @override
  bool get isSupported => true;

  @override
  Stream<GlobalHotkeyTransition> get transitions {
    // `Stream` has no `whereType`; that is an `Iterable` extension. Map to a
    // nullable transition and drop the nulls instead, so unrecognised payloads
    // are silently ignored rather than surfacing as stream errors.
    _transitionsCache ??= _eventChannel
        .receiveBroadcastStream()
        .map(_parseTransition)
        .where((transition) => transition != null)
        .cast<GlobalHotkeyTransition>();
    return _transitionsCache!;
  }

  @override
  Future<void> setBinding(PushToTalkKeyBinding? binding) async {
    try {
      if (binding == null) {
        await _methodChannel.invokeMethod<void>('setBinding', null);
        return;
      }

      final payload = windowsGlobalHotkeyPayloadForBinding(binding);
      if (payload == null) {
        _logger.warning('Failed to convert key binding to Windows VK code');
        return;
      }

      await _methodChannel.invokeMethod<void>('setBinding', payload);
    } on PlatformException catch (e) {
      _logger.warning('Failed to set global hotkey binding: ${e.message}');
    }
  }

  @override
  bool supportsBinding(PushToTalkKeyBinding binding) =>
      windowsGlobalHotkeyPayloadForBinding(binding) != null;

  @override
  Future<bool> setActive(bool active) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setActive',
        <String, Object>{'active': active},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.warning('Failed to set global hotkey active state: ${e.message}');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _transitionsCache = null;
  }

  /// Parses a raw event channel payload into a [GlobalHotkeyTransition].
  ///
  /// Returns null for anything that is not a recognised transition string, so
  /// unknown payloads are dropped instead of throwing.
  GlobalHotkeyTransition? _parseTransition(Object? event) {
    switch (event) {
      case 'down':
        return GlobalHotkeyTransition.down;
      case 'up':
        return GlobalHotkeyTransition.up;
      default:
        _logger.warning('Unknown hotkey transition event: $event');
        return null;
    }
  }
}
