import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('PreferencesRepository call talk mode preference', () {
    test('defaults to hands-free when not saved', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      final enabled = await repository.getPreferredCallPushToTalkEnabled();

      expect(enabled, isFalse);
    });

    test('persists push-to-talk enabled', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      await repository.setPreferredCallPushToTalkEnabled(true);

      expect(await repository.getPreferredCallPushToTalkEnabled(), isTrue);
    });

    test('persists hands-free after push-to-talk was enabled', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      await repository.setPreferredCallPushToTalkEnabled(true);
      await repository.setPreferredCallPushToTalkEnabled(false);

      expect(await repository.getPreferredCallPushToTalkEnabled(), isFalse);
    });
  });

  group('PreferencesRepository keyboard push-to-talk key preference', () {
    test('defaults to unset when not saved', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      final binding = await repository.getPreferredCallPushToTalkKeyBinding();

      expect(binding, isNull);
    });

    test('persists keyboard push-to-talk binding', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);
      final binding = PushToTalkKeyBinding(
        primaryLogicalKeyId: LogicalKeyboardKey.space.keyId,
        modifiers: const [PushToTalkKeyModifier.control],
        displayTokens: const ['Ctrl', 'Space'],
      );

      await repository.setPreferredCallPushToTalkKeyBinding(binding);

      expect(await repository.getPreferredCallPushToTalkKeyBinding(), binding);
    });

    test('clears keyboard push-to-talk binding', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);
      final binding = PushToTalkKeyBinding(
        primaryLogicalKeyId: LogicalKeyboardKey.keyV.keyId,
        modifiers: const [],
        displayTokens: const ['V'],
      );

      await repository.setPreferredCallPushToTalkKeyBinding(binding);
      await repository.setPreferredCallPushToTalkKeyBinding(null);

      expect(await repository.getPreferredCallPushToTalkKeyBinding(), isNull);
    });
  });

  group('PreferencesRepository idle disconnect timeout preference', () {
    test('defaults to 3 minutes when not saved', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      final timeoutSeconds = await repository
          .getPreferredCallIdleDisconnectTimeoutSeconds();

      expect(timeoutSeconds, 180);
    });

    test('persists all supported idle disconnect timeout options', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      for (final timeoutSeconds in const [30, 60, 180, 300, 600, 1800]) {
        await repository.setPreferredCallIdleDisconnectTimeoutSeconds(
          timeoutSeconds,
        );

        expect(
          await repository.getPreferredCallIdleDisconnectTimeoutSeconds(),
          timeoutSeconds,
        );
      }
    });

    test('rejects unsupported idle disconnect timeout values', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      expect(
        () => repository.setPreferredCallIdleDisconnectTimeoutSeconds(0),
        throwsArgumentError,
      );
      expect(
        () => repository.setPreferredCallIdleDisconnectTimeoutSeconds(120),
        throwsArgumentError,
      );
    });
  });

  group('PreferencesRepository global hotkey preference', () {
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

    Future<PreferencesRepository> buildRepository() async {
      final store = InMemoryStore();
      await store.initialize();
      return PreferencesRepository(store);
    }

    test('defaults to no bindings when nothing was saved', () async {
      final repository = await buildRepository();

      expect(await repository.getPreferredGlobalHotkeyBindings(), isEmpty);
    });

    test('persists a binding per action', () async {
      final repository = await buildRepository();

      await repository.setPreferredGlobalHotkeyBinding(
        GlobalHotkeyAction.pushToTalk,
        holdBinding,
      );
      await repository.setPreferredGlobalHotkeyBinding(
        GlobalHotkeyAction.interrupt,
        interruptBinding,
      );

      expect(await repository.getPreferredGlobalHotkeyBindings(), {
        GlobalHotkeyAction.pushToTalk: holdBinding,
        GlobalHotkeyAction.interrupt: interruptBinding,
      });
    });

    test('clears one action without touching the others', () async {
      final repository = await buildRepository();

      await repository.setPreferredGlobalHotkeyBinding(
        GlobalHotkeyAction.pushToTalk,
        holdBinding,
      );
      await repository.setPreferredGlobalHotkeyBinding(
        GlobalHotkeyAction.interrupt,
        interruptBinding,
      );
      await repository.setPreferredGlobalHotkeyBinding(
        GlobalHotkeyAction.pushToTalk,
        null,
      );

      expect(await repository.getPreferredGlobalHotkeyBindings(), {
        GlobalHotkeyAction.interrupt: interruptBinding,
      });
    });

    test('drops entries that cannot be read back', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);
      await store.set('preferred_global_hotkey_bindings', <String, dynamic>{
        'interrupt': interruptBinding.toJson(),
        'pushToTalk': 'Ctrl+Space',
        'summonHelicopter': holdBinding.toJson(),
      });

      expect(await repository.getPreferredGlobalHotkeyBindings(), {
        GlobalHotkeyAction.interrupt: interruptBinding,
      });
    });
  });
}
