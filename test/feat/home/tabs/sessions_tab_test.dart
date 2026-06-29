import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/home/tabs/sessions.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/call_session.dart';

void main() {
  setUp(() async {
    AppContainer.reset();
    await AppContainer.initialize(store: _MemoryKeyValueStore());
  });

  tearDown(AppContainer.reset);

  // Scenario: the sessions tab is mounted for the first time while the repository call is still
  // pending.
  //
  // The tab must deterministically start the first-page load from provider initialization, not from a
  // fragile widget-listener timing path. While the call is pending the initial spinner is visible;
  // when the repository completes, the spinner disappears, the returned row is rendered, and no
  // duplicate first-page request is issued by rebuilds.
  testWidgets('initialLoad', (tester) async {
    final repository = _CompletingCallSessionRepository();
    AppContainer.setOverridesForTesting(callSessions: repository);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SessionsTab()),
        ),
      ),
    );

    await tester.pump();

    expect(repository.listCalls, hasLength(1));
    expect(repository.listCalls.single.cursor, isNull);
    expect(repository.listCalls.single.limit, 30);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete(
      CallSessionPage(
        items: [
          CallSession(
            id: 'session-one',
            startedAt: DateTime.utc(2026, 1, 1, 12),
            endedAt: DateTime.utc(2026, 1, 1, 12, 3),
          ),
        ],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(repository.listCalls, hasLength(1));
  });
}

final class _ListCall {
  final String? cursor;
  final int? limit;

  const _ListCall({required this.cursor, required this.limit});
}

final class _CompletingCallSessionRepository implements CallSessionRepository {
  final List<_ListCall> listCalls = <_ListCall>[];
  final Completer<CallSessionPage> _firstPage = Completer<CallSessionPage>();

  void complete(CallSessionPage page) {
    _firstPage.complete(page);
  }

  @override
  Future<int> bulkDelete(List<String> ids) async => ids.length;

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<CallSession?> getById(String id) async => null;

  @override
  Future<CallSessionPage> list({String? cursor, int? limit}) {
    listCalls.add(_ListCall(cursor: cursor, limit: limit));
    return _firstPage.future;
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
  Future<String> getFilePath() async => 'memory';
}
