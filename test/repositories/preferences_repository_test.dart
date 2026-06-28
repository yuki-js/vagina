import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/data/in_memory_store.dart';
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

  group('PreferencesRepository idle disconnect timeout preference', () {
    test('defaults to 3 minutes when not saved', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      final timeoutSeconds = await repository
          .getPreferredCallIdleDisconnectTimeoutSeconds();

      expect(timeoutSeconds, AppConfig.defaultSilenceTimeoutSeconds);
    });

    test('persists all supported idle disconnect timeout options', () async {
      final store = InMemoryStore();
      await store.initialize();
      final repository = PreferencesRepository(store);

      for (final timeoutSeconds in AppConfig.silenceTimeoutSecondsOptions) {
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
}
