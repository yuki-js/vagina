import 'package:flutter_test/flutter_test.dart';
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
}
