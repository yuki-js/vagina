import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/session/state/session_history_providers.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/repositories/api_call_session_repository.dart';

void main() {
  setUp(() async {
    AppContainer.reset();
    await AppContainer.initialize(store: _MemoryKeyValueStore());
  });

  tearDown(AppContainer.reset);

  test('loads first page then appends next page by cursor', () async {
    final repository = _FakeCallSessionRepository(
      pages: <String?, CallSessionPage>{
        null: CallSessionPage(items: [_session('one')], nextCursor: 'cursor-2'),
        'cursor-2': CallSessionPage(items: [_session('two')], nextCursor: null),
      },
    );
    AppContainer.setOverridesForTesting(callSessions: repository);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(sessionHistoryControllerProvider).isInitialLoading,
      isTrue,
    );
    await container
        .read(sessionHistoryControllerProvider.notifier)
        .loadFirstPage();
    expect(
      container
          .read(sessionHistoryControllerProvider)
          .items
          .map((session) => session.id),
      ['one'],
    );
    expect(
      container.read(sessionHistoryControllerProvider).nextCursor,
      'cursor-2',
    );

    await container.read(sessionHistoryControllerProvider.notifier).loadMore();

    expect(
      container
          .read(sessionHistoryControllerProvider)
          .items
          .map((session) => session.id),
      ['one', 'two'],
    );
    expect(container.read(sessionHistoryControllerProvider).nextCursor, isNull);
    expect(repository.listCalls.map((call) => call.cursor), [null, 'cursor-2']);
  });

  test('refresh reloads first page and clears previous cursor state', () async {
    final repository = _FakeCallSessionRepository(
      pages: <String?, CallSessionPage>{
        null: CallSessionPage(items: [_session('fresh')], nextCursor: null),
      },
    );
    AppContainer.setOverridesForTesting(callSessions: repository);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(sessionHistoryControllerProvider);
    await container
        .read(sessionHistoryControllerProvider.notifier)
        .loadFirstPage();
    await container.read(sessionHistoryControllerProvider.notifier).refresh();

    expect(
      container
          .read(sessionHistoryControllerProvider)
          .items
          .map((session) => session.id),
      ['fresh'],
    );
    expect(container.read(sessionHistoryControllerProvider).nextCursor, isNull);
    expect(repository.listCalls.map((call) => call.cursor), [null, null]);
  });

  test(
    'session detail provider surfaces saved-thread display failures',
    () async {
      final repository = _FakeCallSessionRepository(
        pages: const <String?, CallSessionPage>{},
        detailError: SavedThreadCannotBeDisplayedException('bad-thread'),
      );
      AppContainer.setOverridesForTesting(callSessions: repository);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = sessionDetailProvider('broken-session');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await pumpEventQueue();

      final value = container.read(provider);
      expect(value.hasError, isTrue);
      expect(value.error, isA<SavedThreadCannotBeDisplayedException>());
    },
  );

  test(
    'bulk delete delegates ids and removes selected sessions from state',
    () async {
      final repository = _FakeCallSessionRepository(
        pages: <String?, CallSessionPage>{
          null: CallSessionPage(
            items: [_session('one'), _session('two'), _session('three')],
            nextCursor: null,
          ),
        },
      );
      AppContainer.setOverridesForTesting(callSessions: repository);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sessionHistoryControllerProvider);
      await container
          .read(sessionHistoryControllerProvider.notifier)
          .loadFirstPage();

      await container
          .read(sessionHistoryControllerProvider.notifier)
          .bulkDelete(['one', 'three']);

      expect(repository.bulkDeleteCalls.single, ['one', 'three']);
      expect(
        container
            .read(sessionHistoryControllerProvider)
            .items
            .map((session) => session.id),
        ['two'],
      );
    },
  );
}

CallSession _session(String id) {
  return CallSession(
    id: id,
    startedAt: DateTime.utc(2026, 1, 1),
    endedAt: DateTime.utc(2026, 1, 1, 0, 1),
  );
}

final class _ListCall {
  final String? cursor;
  final int? limit;

  const _ListCall({required this.cursor, required this.limit});
}

final class _FakeCallSessionRepository implements CallSessionRepository {
  final Map<String?, CallSessionPage> pages;
  final List<_ListCall> listCalls = <_ListCall>[];
  final List<List<String>> bulkDeleteCalls = <List<String>>[];
  final Object? detailError;

  _FakeCallSessionRepository({required this.pages, this.detailError});

  @override
  Future<int> bulkDelete(List<String> ids) async {
    bulkDeleteCalls.add(List<String>.from(ids));
    return 999;
  }

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<CallSession?> getById(String id) async {
    final error = detailError;
    if (error != null) {
      throw error;
    }
    return null;
  }

  @override
  Future<CallSessionPage> list({String? cursor, int? limit}) async {
    listCalls.add(_ListCall(cursor: cursor, limit: limit));
    return pages[cursor] ?? const CallSessionPage(items: [], nextCursor: null);
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
