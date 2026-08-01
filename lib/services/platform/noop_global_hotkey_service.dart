import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

/// No-op implementation of GlobalHotkeyService for non-Windows platforms.
///
/// Returns false for isSupported and provides empty/do-nothing implementations
/// of all methods. Used on macOS, Linux, Web, and other platforms where
/// global hotkey support is not available.
class NoopGlobalHotkeyService implements GlobalHotkeyService {
  @override
  bool get isSupported => false;

  @override
  Stream<GlobalHotkeyTransition> get transitions =>
      const Stream<GlobalHotkeyTransition>.empty().asBroadcastStream();

  @override
  Future<void> setBinding(PushToTalkKeyBinding? binding) async {}

  @override
  bool supportsBinding(PushToTalkKeyBinding binding) => false;

  @override
  Future<bool> setActive(bool active) async => false;

  @override
  Future<void> dispose() async {}
}
