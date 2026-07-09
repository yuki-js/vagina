import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/oobe/screens/authentication.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  testWidgets('renders only server-provided OIDC providers', (tester) async {
    await tester.pumpWidget(
      _LocalizedApp(
        child: AuthenticationScreen(
          announcementService: AnnouncementService(
            preferencesRepository: PreferencesRepository(
              _MemoryKeyValueStore(),
            ),
          ),
          providers: const <AuthProvider>[
            AuthProvider(
              id: 'github',
              name: 'GitHub',
              icon: Icons.code,
              color: Color(0xFF181717),
            ),
          ],
          onProviderTap: (_) async {},
          onRetryLoadProviders: () {},
          onBack: () {},
        ),
      ),
    );

    expect(find.textContaining('GitHub'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('Twitter'), findsNothing);
  });

  testWidgets('renders empty state when no OIDC providers are configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedApp(
        child: AuthenticationScreen(
          announcementService: AnnouncementService(
            preferencesRepository: PreferencesRepository(
              _MemoryKeyValueStore(),
            ),
          ),
          providers: const <AuthProvider>[],
          onProviderTap: (_) async {},
          onRetryLoadProviders: () {},
          onBack: () {},
        ),
      ),
    );

    expect(
      find.text('No sign-in providers are configured for this server.'),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsNothing);
  });
}

class _LocalizedApp extends StatelessWidget {
  final Widget child;

  const _LocalizedApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

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
  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async => _data.containsKey(key);

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<String> getFilePath() async => 'memory://authentication-screen-test';
}
