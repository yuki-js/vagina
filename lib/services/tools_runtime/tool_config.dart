import 'dart:convert';

import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';

/// Utility for managing tool configuration on the virtual filesystem.
class ToolConfig {
  final FilesystemApi _filesystem;
  final String _configPath;

  ToolConfig(
    this._filesystem, {
    String configPath = '/.tool_config.json',
  }) : _configPath = configPath;

  /// Load all configuration at once.
  Future<Map<String, dynamic>> loadAll() async {
    final data = await _filesystem.read(_configPath);
    if (data == null || data['content'] is! String) {
      return {};
    }

    final content = data['content'] as String;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return {};
    }

    return {};
  }

  /// Get a specific configuration value.
  Future<dynamic> get(String key, {dynamic defaultValue}) async {
    final config = await loadAll();
    return config[key] ?? defaultValue;
  }

  /// Set a specific configuration value.
  Future<void> set(String key, dynamic value) async {
    final config = await loadAll();
    config[key] = value;
    await _filesystem.write(_configPath, jsonEncode(config));
  }

  /// Remove a configuration entry.
  Future<bool> remove(String key) async {
    final config = await loadAll();
    if (!config.containsKey(key)) {
      return false;
    }
    config.remove(key);
    await _filesystem.write(_configPath, jsonEncode(config));
    return true;
  }

  /// Check whether a configuration key exists.
  Future<bool> has(String key) async {
    final config = await loadAll();
    return config.containsKey(key);
  }

  /// Clear all configuration.
  Future<void> clear() async {
    await _filesystem.delete(_configPath);
  }

  /// Get a configuration value as a string.
  Future<String?> getString(String key) async {
    final value = await get(key);
    if (value is String) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as a boolean.
  Future<bool?> getBool(String key) async {
    final value = await get(key);
    if (value is bool) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as an integer.
  Future<int?> getInt(String key) async {
    final value = await get(key);
    if (value is int) {
      return value;
    }
    return null;
  }

  /// Get a configuration value as a double.
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

  /// Get a configuration value as a map.
  Future<Map<String, dynamic>?> getMap(String key) async {
    final value = await get(key);
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  /// Get a configuration value as a list.
  Future<List<dynamic>?> getList(String key) async {
    final value = await get(key);
    if (value is List<dynamic>) {
      return value;
    }
    return null;
  }
}
