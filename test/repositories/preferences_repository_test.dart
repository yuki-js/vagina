import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('PreferencesRepository auth refresh token', () {
    late PreferencesRepository repository;
    late InMemoryStore store;

    setUp(() async {
      store = InMemoryStore();
      await store.initialize();
      repository = PreferencesRepository(store);
    });

    test('save/get should round-trip refresh token', () async {
      await repository.saveAuthRefreshToken('refresh-token');
      final restored = await repository.getAuthRefreshToken();

      expect(restored, 'refresh-token');
    });

    test('clear should remove persisted refresh token', () async {
      await repository.saveAuthRefreshToken('refresh-token');

      await repository.clearAuthRefreshToken();

      final restored = await repository.getAuthRefreshToken();
      expect(restored, isNull);
    });

    test('get should migrate legacy auth_session format', () async {
      await store.set('auth_session', {'refreshToken': 'legacy-refresh-token'});

      final restored = await repository.getAuthRefreshToken();

      expect(restored, 'legacy-refresh-token');
      expect(await store.get('auth_refresh_token'), 'legacy-refresh-token');
      expect(await store.get('auth_session'), isNull);
    });

    test('pending PKCE verifier should be consumed once', () async {
      await repository.savePendingPkceVerifier('verifier-1');

      final first = await repository.consumePendingPkceVerifier();
      final second = await repository.consumePendingPkceVerifier();

      expect(first, 'verifier-1');
      expect(second, isNull);
    });

    test('pending provider should be consumed once', () async {
      await repository.savePendingOidcProvider('github');

      final first = await repository.consumePendingOidcProvider();
      final second = await repository.consumePendingOidcProvider();

      expect(first, 'github');
      expect(second, isNull);
    });
  });
}
