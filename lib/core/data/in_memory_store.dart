import 'package:vagina/interfaces/key_value_store.dart';

/// In-memory implementation of [`KeyValueStore`](lib/interfaces/key_value_store.dart:2).
///
/// Intended for tests and scenarios where disk/web persistence is not desired.
class InMemoryStore implements KeyValueStore {
  bool _initialized = false;
  final Map<String, dynamic> _data = {};

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Store not initialized. Call initialize() first.');
    }
  }

  @override
  Future<Map<String, dynamic>> load() async {
    _ensureInitialized();
    return Map<String, dynamic>.from(_data);
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _ensureInitialized();
    _data
      ..clear()
      ..addAll(data);
  }

  @override
  Future<dynamic> get(String key) async {
    _ensureInitialized();
    return _data[key];
  }

  @override
  Future<void> set(String key, dynamic value) async {
    _ensureInitialized();
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _ensureInitialized();
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async {
    _ensureInitialized();
    return _data.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    _data.clear();
  }

  @override
  Future<String> getFilePath() async {
    // Useful for debugging / test logs.
    return 'in-memory';
  }
}
