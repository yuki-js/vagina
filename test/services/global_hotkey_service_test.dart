import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'app.aoki.yuki.vagina/global_hotkeys',
  );
  const MethodCodec codec = StandardMethodCodec();
  const GlobalHotkeyBinding holdBinding = GlobalHotkeyBinding(
    virtualKeyCode: 0x20,
    modifiers: [GlobalHotkeyModifier.control],
    displayTokens: ['Ctrl', 'Space'],
  );
  const GlobalHotkeyBinding interruptBinding = GlobalHotkeyBinding(
    virtualKeyCode: 0x78,
    modifiers: [GlobalHotkeyModifier.alt],
    displayTokens: ['Alt', 'F9'],
  );

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Records the calls the service makes and answers them with [rejectedIds].
  List<MethodCall> mockPlatform({List<String> rejectedIds = const <String>[]}) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'setHotkeys') {
        return rejectedIds;
      }
      return null;
    });
    return calls;
  }

  Future<void> emitPlatformCall(String method, Object? arguments) {
    return messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('registers every binding with its platform representation', () async {
    final calls = mockPlatform();
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);

    final rejected = await service.apply({
      GlobalHotkeyAction.pushToTalk: holdBinding,
      GlobalHotkeyAction.interrupt: interruptBinding,
    });

    expect(rejected, isEmpty);
    expect(calls.single.method, 'setHotkeys');
    expect(calls.single.arguments, [
      {
        'id': 'pushToTalk',
        'virtualKeyCode': 0x20,
        'modifiers': 0x0002,
        'tracksRelease': true,
      },
      {
        'id': 'interrupt',
        'virtualKeyCode': 0x78,
        'modifiers': 0x0001,
        'tracksRelease': false,
      },
    ]);
  });

  test('reports the actions the platform refused', () async {
    mockPlatform(rejectedIds: ['interrupt']);
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);

    final rejected = await service.apply({
      GlobalHotkeyAction.pushToTalk: holdBinding,
      GlobalHotkeyAction.interrupt: interruptBinding,
    });

    expect(rejected, {GlobalHotkeyAction.interrupt});
  });

  test('treats a platform failure as every binding being rejected', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'global_hotkeys_unavailable');
    });
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);

    final rejected = await service.apply({
      GlobalHotkeyAction.pushToTalk: holdBinding,
    });

    expect(rejected, {GlobalHotkeyAction.pushToTalk});
  });

  test('releases the hotkeys when applying an empty set', () async {
    final calls = mockPlatform();
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);

    final rejected = await service.apply(
      const <GlobalHotkeyAction, GlobalHotkeyBinding>{},
    );

    expect(rejected, isEmpty);
    expect(calls.single.method, 'clearHotkeys');
  });

  test('surfaces presses and releases as events', () async {
    mockPlatform();
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);
    final events = <GlobalHotkeyEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await emitPlatformCall('onHotkeyPressed', 'pushToTalk');
    await emitPlatformCall('onHotkeyReleased', 'pushToTalk');
    await emitPlatformCall('onHotkeyPressed', 'muteToggle');

    expect(events.map((event) => event.action), [
      GlobalHotkeyAction.pushToTalk,
      GlobalHotkeyAction.pushToTalk,
      GlobalHotkeyAction.muteToggle,
    ]);
    expect(events.map((event) => event.isPressed), [true, false, true]);
  });

  test('ignores platform calls it does not recognize', () async {
    mockPlatform();
    final service = GlobalHotkeyService(isSupported: true);
    addTearDown(service.dispose);
    final events = <GlobalHotkeyEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await emitPlatformCall('onHotkeyPressed', 'openThePodBayDoors');
    await emitPlatformCall('onHotkeyPressed', 42);
    await emitPlatformCall('onSomethingElse', 'pushToTalk');

    expect(events, isEmpty);
  });

  test('rejects every binding on an unsupported platform', () async {
    final calls = mockPlatform();
    final service = GlobalHotkeyService(isSupported: false);
    addTearDown(service.dispose);

    final rejected = await service.apply({
      GlobalHotkeyAction.pushToTalk: holdBinding,
    });

    expect(rejected, {GlobalHotkeyAction.pushToTalk});
    expect(calls, isEmpty);
  });

  test('releases the hotkeys when disposed', () async {
    final calls = mockPlatform();
    final service = GlobalHotkeyService(isSupported: true);

    await service.apply({GlobalHotkeyAction.pushToTalk: holdBinding});
    await service.dispose();

    expect(calls.map((call) => call.method), ['setHotkeys', 'clearHotkeys']);

    // A disposed service stops touching the platform.
    await service.apply({GlobalHotkeyAction.pushToTalk: holdBinding});
    expect(calls.map((call) => call.method), ['setHotkeys', 'clearHotkeys']);
  });
}
