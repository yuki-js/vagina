import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/controllers/global_hotkey_call_controller.dart';
import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

void main() {
  late List<String> actions;
  late bool isPushToTalkMode;
  late GlobalHotkeyCallController controller;

  setUp(() {
    actions = <String>[];
    isPushToTalkMode = true;
    controller = GlobalHotkeyCallController(
      isPushToTalkMode: () => isPushToTalkMode,
      onInputStart: () => actions.add('start'),
      onInputSend: () => actions.add('send'),
      onInputCancel: () => actions.add('cancel'),
      onInterrupt: () => actions.add('interrupt'),
      onMuteToggle: () => actions.add('mute'),
    );
  });

  void press(GlobalHotkeyAction action) {
    controller.handle(GlobalHotkeyEvent(action: action, isPressed: true));
  }

  void release(GlobalHotkeyAction action) {
    controller.handle(GlobalHotkeyEvent(action: action, isPressed: false));
  }

  group('hold-to-talk', () {
    test('starts on press and sends on release', () {
      press(GlobalHotkeyAction.pushToTalk);
      expect(controller.isInputActive, isTrue);
      release(GlobalHotkeyAction.pushToTalk);

      expect(actions, ['start', 'send']);
      expect(controller.isInputActive, isFalse);
    });

    test('ignores a repeated press while the turn is running', () {
      press(GlobalHotkeyAction.pushToTalk);
      press(GlobalHotkeyAction.pushToTalk);
      release(GlobalHotkeyAction.pushToTalk);

      expect(actions, ['start', 'send']);
    });

    test('ignores a release with no turn running', () {
      release(GlobalHotkeyAction.pushToTalk);

      expect(actions, isEmpty);
    });
  });

  group('start and send toggle', () {
    test('starts on the first press and sends on the second', () {
      press(GlobalHotkeyAction.pushToTalkToggle);
      expect(controller.isInputActive, isTrue);
      press(GlobalHotkeyAction.pushToTalkToggle);

      expect(actions, ['start', 'send']);
      expect(controller.isInputActive, isFalse);
    });

    test('ignores its own release', () {
      press(GlobalHotkeyAction.pushToTalkToggle);
      release(GlobalHotkeyAction.pushToTalkToggle);

      expect(actions, ['start']);
      expect(controller.isInputActive, isTrue);
    });

    test('sends a turn that hold-to-talk started', () {
      press(GlobalHotkeyAction.pushToTalk);
      press(GlobalHotkeyAction.pushToTalkToggle);

      expect(actions, ['start', 'send']);
    });

    test('does not start a second turn on top of a held one', () {
      press(GlobalHotkeyAction.pushToTalkToggle);
      press(GlobalHotkeyAction.pushToTalk);

      expect(actions, ['start']);
    });
  });

  group('discarding input', () {
    test('discards a running turn', () {
      press(GlobalHotkeyAction.pushToTalkToggle);
      press(GlobalHotkeyAction.cancelInput);

      expect(actions, ['start', 'cancel']);
      expect(controller.isInputActive, isFalse);
    });

    test('reaches the call even with no hotkey-driven turn running', () {
      press(GlobalHotkeyAction.cancelInput);

      expect(actions, ['cancel']);
    });

    test('leaves the next press able to start a turn', () {
      press(GlobalHotkeyAction.pushToTalk);
      press(GlobalHotkeyAction.cancelInput);
      press(GlobalHotkeyAction.pushToTalk);

      expect(actions, ['start', 'cancel', 'start']);
    });
  });

  group('hands-free mode', () {
    setUp(() {
      isPushToTalkMode = false;
    });

    test('ignores presses that would start an input turn', () {
      press(GlobalHotkeyAction.pushToTalk);
      release(GlobalHotkeyAction.pushToTalk);
      press(GlobalHotkeyAction.pushToTalkToggle);

      expect(actions, isEmpty);
      expect(controller.isInputActive, isFalse);
    });

    test('still interrupts and toggles mute', () {
      press(GlobalHotkeyAction.interrupt);
      press(GlobalHotkeyAction.muteToggle);

      expect(actions, ['interrupt', 'mute']);
    });
  });

  group('reset', () {
    test('drops a running turn without sending or discarding it', () {
      press(GlobalHotkeyAction.pushToTalk);
      controller.reset();

      expect(actions, ['start']);
      expect(controller.isInputActive, isFalse);
    });

    test('leaves a later release with nothing to send', () {
      press(GlobalHotkeyAction.pushToTalk);
      controller.reset();
      release(GlobalHotkeyAction.pushToTalk);

      expect(actions, ['start']);
    });
  });

  test('interrupt and mute act once per press', () {
    press(GlobalHotkeyAction.interrupt);
    release(GlobalHotkeyAction.interrupt);
    press(GlobalHotkeyAction.muteToggle);
    release(GlobalHotkeyAction.muteToggle);

    expect(actions, ['interrupt', 'mute']);
  });
}
