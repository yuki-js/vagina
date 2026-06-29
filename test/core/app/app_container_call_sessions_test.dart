import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/models/call_session.dart';

void main() {
  tearDown(AppContainer.reset);

  test('callSessions supports test override', () async {
    final override = _FakeCallSessionRepository();

    await AppContainer.initialize(store: _MemoryKeyValueStore());
    AppContainer.setOverridesForTesting(callSessions: override);

    expect(AppContainer.callSessions, same(override));
  });
}

final class _FakeCallSessionRepository implements CallSessionRepository {
  @override
  Future<int> bulkDelete(List<String> ids) async => ids.length;

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<CallSession?> getById(String id) async => null;

  @override
  Future<CallSessionPage> list({String? cursor, int? limit}) async {
    return const CallSessionPage(items: [], nextCursor: null);
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
