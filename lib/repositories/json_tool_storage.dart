import 'package:vagina/interfaces/tool_storage.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';

/// JSON-based implementation of ToolStorage with per-tool namespacing
///
/// All tools' data is stored under a single key in the underlying store,
/// with entries prefixed by toolKey to create isolated namespaces.
class JsonToolStorage implements ToolStorage {
  static const _tag = 'ToolStorage';
  static const _rootKey = 'tool_storage';

  final KeyValueStore _store;
  final LogService _logService;

  JsonToolStorage(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  /// Create the full namespaced key for a tool's data entry
  String _makeKey(String toolKey, String key) => '$toolKey:$key';

  /// Extract toolKey from a full namespaced key
  String? _extractToolKey(String fullKey) {
    final parts = fullKey.split(':');
    if (parts.length >= 2) {
      return parts[0];
    }
    return null;
  }

  /// Extract the original key from a full namespaced key
  String? _extractKey(String fullKey) {
    final colonIndex = fullKey.indexOf(':');
    if (colonIndex >= 0 && colonIndex < fullKey.length - 1) {
      return fullKey.substring(colonIndex + 1);
    }
    return null;
  }

  /// Get all tool storage data
  Future<Map<String, dynamic>> _getAllData() async {
    final data = await _store.get(_rootKey);
    if (data == null) {
      return {};
    }
    if (data is! Map) {
      _logService.warn(_tag, 'Invalid tool storage data type');
      return {};
    }
    return Map<String, dynamic>.from(data);
  }

  /// Save all tool storage data
  Future<void> _saveAllData(Map<String, dynamic> data) async {
    await _store.set(_rootKey, data);
  }

  @override
  Future<void> save(String toolKey, String key, dynamic value) async {
    _logService.debug(_tag, 'Saving for tool $toolKey: $key');

    final fullKey = _makeKey(toolKey, key);
    final allData = await _getAllData();

    allData[fullKey] = value;
    await _saveAllData(allData);

    _logService.info(_tag, 'Saved for tool $toolKey: $key');
  }

  @override
  Future<dynamic> get(String toolKey, String key) async {
    final fullKey = _makeKey(toolKey, key);
    final allData = await _getAllData();

    if (!allData.containsKey(fullKey)) {
      _logService.debug(_tag, 'Key not found for tool $toolKey: $key');
      return null;
    }

    return allData[fullKey];
  }

  @override
  Future<Map<String, dynamic>> listAll(String toolKey) async {
    final allData = await _getAllData();
    final result = <String, dynamic>{};

    // Filter entries that belong to this tool and strip the prefix
    for (final entry in allData.entries) {
      final entryToolKey = _extractToolKey(entry.key);
      if (entryToolKey == toolKey) {
        final originalKey = _extractKey(entry.key);
        if (originalKey != null) {
          result[originalKey] = entry.value;
        }
      }
    }

    _logService.debug(
        _tag, 'Listed ${result.length} entries for tool $toolKey');
    return result;
  }

  @override
  Future<bool> delete(String toolKey, String key) async {
    _logService.debug(_tag, 'Deleting for tool $toolKey: $key');

    final fullKey = _makeKey(toolKey, key);
    final allData = await _getAllData();

    if (!allData.containsKey(fullKey)) {
      _logService.warn(_tag, 'Key not found for tool $toolKey: $key');
      return false;
    }

    allData.remove(fullKey);
    await _saveAllData(allData);

    _logService.info(_tag, 'Deleted for tool $toolKey: $key');
    return true;
  }

  @override
  Future<void> deleteAll(String toolKey) async {
    _logService.info(_tag, 'Deleting all data for tool $toolKey');

    final allData = await _getAllData();

    // Remove all entries for this tool
    final keysToRemove = <String>[];
    for (final key in allData.keys) {
      final entryToolKey = _extractToolKey(key);
      if (entryToolKey == toolKey) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      allData.remove(key);
    }

    await _saveAllData(allData);
    _logService.info(
        _tag, 'Deleted ${keysToRemove.length} entries for tool $toolKey');
  }
}
