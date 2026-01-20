import 'dart:convert';
import 'package:vagina/services/tools_runtime/apis/tool_storage_api.dart';

/// Utility for managing tool-specific configuration and settings
/// 
/// Tools can use this to easily store and retrieve their configuration
/// in the tool-isolated storage namespace.
class ToolConfig {
  final ToolStorageApi _storage;
  static const String _configKey = '_tool_config';

  ToolConfig(this._storage);

  /// Load all configuration at once
  /// 
  /// Returns a map of configuration settings, or an empty map if not set.
  Future<Map<String, dynamic>> loadAll() async {
    final data = await _storage.get(_configKey);
    if (data == null) {
      return {};
    }
    
    if (data is Map<String, dynamic>) {
      return data;
    }
    
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    
    return {};
  }

  /// Get a specific configuration value
  /// 
  /// Returns the value if found, otherwise returns [defaultValue].
  Future<dynamic> get(String key, {dynamic defaultValue}) async {
    final config = await loadAll();
    return config[key] ?? defaultValue;
  }

  /// Set a specific configuration value
  /// 
  /// The entire configuration map is updated and saved.
  Future<void> set(String key, dynamic value) async {
    final config = await loadAll();
    config[key] = value;
    await _storage.save(_configKey, config);
  }

  /// Remove a configuration entry
  /// 
  /// Returns true if the key existed and was removed.
  Future<bool> remove(String key) async {
    final config = await loadAll();
    if (!config.containsKey(key)) {
      return false;
    }
    config.remove(key);
    await _storage.save(_configKey, config);
    return true;
  }

  /// Check if a configuration key exists
  Future<bool> has(String key) async {
    final config = await loadAll();
    return config.containsKey(key);
  }

  /// Clear all configuration
  Future<void> clear() async {
    await _storage.delete(_configKey);
  }

  /// Get a configuration value as a string
  Future<String?> getString(String key) async {
    final value = await get(key);
    if (value is String) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as a boolean
  Future<bool?> getBool(String key) async {
    final value = await get(key);
    if (value is bool) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as an integer
  Future<int?> getInt(String key) async {
    final value = await get(key);
    if (value is int) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as a double
  Future<double?> getDouble(String key) async {
    final value = await get(key);
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return null;
  }

  /// Get a configuration value as a map
  Future<Map<String, dynamic>?> getMap(String key) async {
    final value = await get(key);
    if (value is Map<String, dynamic>) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as a list
  Future<List<dynamic>?> getList(String key) async {
    final value = await get(key);
    if (value is List<dynamic>) {
      return value;
    }
    return null;
  }
}
