import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/models/user_account_lifecycle.dart';
import 'package:vagina/api/generated/responses/exchange_oidc_login_response.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('AuthCallbackCoordinator', () {
    test('Web accepts only the HTTPS callback', () async {
      final harness = await _Harness.web(
        Uri.parse('https://vagina.app/callback?code=web-code&state=w.state'),
      );

      await harness.coordinator.start();

      expect(harness.exchanges, [('web-code', 'w.state')]);
      expect(harness.webClearCount, 1);
      await harness.dispose();
    });

    test('Web rejects the native custom scheme callback', () async {
      final harness = await _Harness.web(
        Uri.parse(
          'app.aoki.yuki.vagina://oauth/callback?code=code&state=w.state',
        ),
      );

      await harness.coordinator.start();

      expect(harness.exchanges, isEmpty);
      await harness.dispose();
    });

    test('native accepts cold-start custom scheme callback', () async {
      final harness = await _Harness.native(
        initialUri: Uri.parse(
          'app.aoki.yuki.vagina://oauth/callback?code=native-code&state=m.state',
        ),
      );

      await harness.coordinator.start();

      expect(harness.exchanges, [('native-code', 'm.state')]);
      await harness.dispose();
    });

    test(
      'native accepts warm callback and suppresses duplicate state',
      () async {
        final stream = StreamController<Uri>();
        final harness = await _Harness.native(stream: stream.stream);
        await harness.coordinator.start();

        final callback = Uri.parse(
          'app.aoki.yuki.vagina://oauth/callback?code=code&state=d.state',
        );
        stream.add(callback);
        stream.add(callback);
        await Future<void>.delayed(Duration.zero);

        expect(harness.exchanges, [('code', 'd.state')]);
        await stream.close();
        await harness.dispose();
      },
    );

    test('native rejects the old HTTPS callback', () async {
      final harness = await _Harness.native(
        initialUri: Uri.parse(
          'https://vagina.app/callback?code=code&state=m.state',
        ),
      );

      await harness.coordinator.start();

      expect(harness.exchanges, isEmpty);
      await harness.dispose();
    });
  });
}

final class _Harness {
  final AuthCallbackCoordinator coordinator;
  final List<(String, String)> exchanges;
  final int Function() _webClearCount;

  _Harness._(this.coordinator, this.exchanges, this._webClearCount);

  int get webClearCount => _webClearCount();

  static Future<_Harness> web(Uri uri) async {
    final exchanges = <(String, String)>[];
    var clearCount = 0;
    final service = await _authService(exchanges);
    return _Harness._(
      AuthCallbackCoordinator(
        authService: service,
        isWeb: true,
        isNative: false,
        webBaseUriProvider: () => uri,
        clearWebTransientParams: () => clearCount += 1,
      ),
      exchanges,
      () => clearCount,
    );
  }

  static Future<_Harness> native({
    Uri? initialUri,
    Stream<Uri> stream = const Stream<Uri>.empty(),
  }) async {
    final exchanges = <(String, String)>[];
    final service = await _authService(exchanges);
    return _Harness._(
      AuthCallbackCoordinator(
        authService: service,
        isWeb: false,
        isNative: true,
        nativeInitialLinkProvider: () async => initialUri,
        nativeUriStreamProvider: () => stream,
      ),
      exchanges,
      () => 0,
    );
  }

  static Future<AuthService> _authService(
    List<(String, String)> exchanges,
  ) async {
    final preferences = PreferencesRepository(_MemoryKeyValueStore());
    await preferences.savePendingPkceVerifier('verifier');
    await preferences.savePendingOidcProvider('harigata');
    return AuthService(
      preferencesRepository: preferences,
      exchangeOidcLoginCall: (provider, body) async {
        exchanges.add((body.code, body.state));
        await preferences.savePendingPkceVerifier('verifier');
        await preferences.savePendingOidcProvider(provider);
        return ExchangeOidcLoginResponse.success(_tokenResponse());
      },
    );
  }

  Future<void> dispose() => coordinator.dispose();
}

AuthTokenResponse _tokenResponse() => AuthTokenResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'Bearer',
  expiresIn: 3600,
  user: User(
    id: 'user-1',
    accountLifecycle: UserAccountLifecycle.active,
    entitlements: const [],
    createdAt: DateTime.utc(2026),
  ),
);

final class _MemoryKeyValueStore implements KeyValueStore {
  final Map<String, dynamic> _data = <String, dynamic>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.from(_data);

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _data
      ..clear()
      ..addAll(data);
  }

  @override
  Future<dynamic> get(String key) async => _data[key];

  @override
  Future<void> set(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> contains(String key) async => _data.containsKey(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<String> getFilePath() async =>
      '/tmp/auth_callback_coordinator_test.json';
}
