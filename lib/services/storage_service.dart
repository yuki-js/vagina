import '../utils/platform_compat.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';
import '../models/android_audio_config.dart';
import '../models/call_session.dart';
import '../models/speed_dial.dart';
import '../utils/url_utils.dart';

// Web support for LocalStorage - conditional import
import 'web_stub/web_stub.dart' 
    if (dart.library.html) 'package:web/web.dart' as web;

/// Service for storing settings as files in the user's Documents directory
/// 
/// Settings are stored in /storage/emulated/0/Documents/VAGINA/ which persists
/// even after the app is uninstalled, allowing users to keep their configuration.
class StorageService {
  static const _configFileName = 'vagina_config.json';
  static const _appFolderName = 'VAGINA';
  static const _tag = 'Storage';
  
  File? _configFile;
  int? _androidSdkVersion;

  /// Get Android SDK version
  Future<int> _getAndroidSdkVersion() async {
    if (_androidSdkVersion != null) return _androidSdkVersion!;
    
    if (PlatformCompat.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _androidSdkVersion = androidInfo.version.sdkInt;
      logService.info(_tag, 'Android SDK version: $_androidSdkVersion');
      return _androidSdkVersion!;
    }
    return 0;
  }

  /// Request storage permission for writing to user's Documents directory
  Future<bool> requestStoragePermission() async {
    logService.info(_tag, 'Requesting storage permission');
    
    if (PlatformCompat.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();
      
      if (sdkVersion >= 30) {
        // Android 11+ (API 30+): Request MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.request();
        logService.info(_tag, 'Manage external storage permission status: $status');
        return status.isGranted;
      } else {
        // Android 10 and below: Request standard storage permission
        final status = await Permission.storage.request();
        logService.info(_tag, 'Storage permission status: $status');
        return status.isGranted;
      }
    }
    
    return true;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    if (PlatformCompat.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();
      
      if (sdkVersion >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      }
      return await Permission.storage.isGranted;
    }
    return true;
  }

  /// Initialize the storage service by getting the config file path
  /// Uses user's Documents directory: /storage/emulated/0/Documents/VAGINA/
  /// Falls back to app documents directory if permission is not granted
  Future<File> _getConfigFile() async {
    if (_configFile != null) return _configFile!;
    
    Directory? directory;
    
    if (PlatformCompat.isAndroid) {
      // Check permission first
      final hasPermission = await hasStoragePermission();
      
      if (hasPermission) {
        // Try to use user's Documents directory (persists after uninstall)
        // Path: /storage/emulated/0/Documents/VAGINA/
        try {
          directory = Directory('/storage/emulated/0/Documents/$_appFolderName');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          logService.info(_tag, 'Using external Documents directory: ${directory.path}');
        } catch (e) {
          logService.warn(_tag, 'Failed to create external directory: $e');
          directory = null;
        }
      }
      
      // Fallback to app-specific directory if permission not granted or directory creation failed
      if (directory == null) {
        final appDir = await getApplicationDocumentsDirectory();
        directory = Directory('${appDir.path}/$_appFolderName');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        logService.warn(_tag, 'Falling back to app documents directory: ${directory.path}');
      }
    } else if (PlatformCompat.isIOS) {
      // iOS: Use app's Documents directory
      final appDir = await getApplicationDocumentsDirectory();
      directory = Directory('${appDir.path}/$_appFolderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else {
      // Desktop platforms
      final home = PlatformCompat.environment['HOME'] ?? PlatformCompat.environment['USERPROFILE'] ?? '.';
      directory = Directory('$home/Documents/$_appFolderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
    
    _configFile = File('${directory.path}/$_configFileName');
    logService.info(_tag, 'Config file path: ${_configFile!.path}');
    return _configFile!;
  }

  /// Load all settings from file or LocalStorage (web)
  Future<Map<String, dynamic>> _loadConfig() async {
    try {
      if (kIsWeb) {
        // Use LocalStorage on web
        final storage = web.window.localStorage;
        final contents = storage['vagina_config'];
        if (contents != null && contents.isNotEmpty) {
          logService.debug(_tag, 'Loaded config from LocalStorage');
          return jsonDecode(contents) as Map<String, dynamic>;
        }
        logService.debug(_tag, 'Config not found in LocalStorage');
        return {};
      } else {
        // Use file system on native platforms
        final file = await _getConfigFile();
        if (await file.exists()) {
          final contents = await file.readAsString();
          logService.debug(_tag, 'Loaded config from file');
          return jsonDecode(contents) as Map<String, dynamic>;
        }
        logService.debug(_tag, 'Config file does not exist yet');
      }
    } catch (e) {
      logService.error(_tag, 'Failed to load config: $e');
    }
    return {};
  }

  /// Save all settings to file or LocalStorage (web)
  Future<void> _saveConfig(Map<String, dynamic> config) async {
    try {
      if (kIsWeb) {
        // Use LocalStorage on web
        final storage = web.window.localStorage;
        storage['vagina_config'] = jsonEncode(config);
        logService.info(_tag, 'Saved config to LocalStorage');
      } else {
        // Use file system on native platforms
        final file = await _getConfigFile();
        await file.writeAsString(jsonEncode(config));
        logService.info(_tag, 'Saved config to file');
      }
    } catch (e) {
      logService.error(_tag, 'Failed to save config: $e');
      rethrow;
    }
  }

  /// Save the Azure OpenAI API key
  Future<void> saveApiKey(String apiKey) async {
    logService.info(_tag, 'Saving API key');
    final config = await _loadConfig();
    config['api_key'] = apiKey;
    await _saveConfig(config);
  }

  /// Get the stored Azure OpenAI API key
  Future<String?> getApiKey() async {
    final config = await _loadConfig();
    final apiKey = config['api_key'] as String?;
    logService.debug(_tag, 'Got API key: ${apiKey != null ? "[exists]" : "[null]"}');
    return apiKey;
  }

  /// Delete the stored API key
  Future<void> deleteApiKey() async {
    logService.info(_tag, 'Deleting API key');
    final config = await _loadConfig();
    config.remove('api_key');
    await _saveConfig(config);
  }

  /// Check if API key is stored
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Save Azure Realtime URL (contains endpoint, deployment, api-version)
  Future<void> saveRealtimeUrl(String url) async {
    logService.info(_tag, 'Saving Realtime URL');
    final config = await _loadConfig();
    config['realtime_url'] = url;
    await _saveConfig(config);
  }

  /// Get Azure Realtime URL
  Future<String?> getRealtimeUrl() async {
    final config = await _loadConfig();
    final url = config['realtime_url'] as String?;
    logService.debug(_tag, 'Got Realtime URL: ${url != null ? "[exists]" : "[null]"}');
    return url;
  }

  /// Delete Azure Realtime URL
  Future<void> deleteRealtimeUrl() async {
    logService.info(_tag, 'Deleting Realtime URL');
    final config = await _loadConfig();
    config.remove('realtime_url');
    await _saveConfig(config);
  }

  /// Parse Realtime URL to extract components
  /// Returns null if URL is invalid
  static Map<String, String>? parseRealtimeUrl(String url) {
    return UrlUtils.parseAzureRealtimeUrl(url);
  }

  /// Check if all Azure settings are configured
  Future<bool> hasAzureConfig() async {
    final apiKey = await getApiKey();
    final realtimeUrl = await getRealtimeUrl();
    
    if (apiKey == null || apiKey.isEmpty) return false;
    if (realtimeUrl == null || realtimeUrl.isEmpty) return false;
    
    // Validate URL format
    final parsed = parseRealtimeUrl(realtimeUrl);
    return parsed != null;
  }

  /// Clear all settings
  Future<void> clearAll() async {
    logService.info(_tag, 'Clearing all settings');
    if (kIsWeb) {
      // Clear LocalStorage on web
      final storage = web.window.localStorage;
      storage.removeItem('vagina_config');
    } else {
      // Clear file on native platforms
      final file = await _getConfigFile();
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
  
  /// Get current config file path for display
  Future<String> getConfigFilePath() async {
    final file = await _getConfigFile();
    return file.path;
  }

  // Memory functions for tool service
  
  /// Save a memory item (for AI long-term memory feature)
  Future<void> saveMemory(String key, String value) async {
    logService.info(_tag, 'Saving memory: $key');
    final config = await _loadConfig();
    final memories = (config['memories'] as Map<String, dynamic>?) ?? {};
    memories[key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    config['memories'] = memories;
    await _saveConfig(config);
  }

  /// Get a memory item
  Future<String?> getMemory(String key) async {
    final config = await _loadConfig();
    final memories = (config['memories'] as Map<String, dynamic>?) ?? {};
    final memory = memories[key] as Map<String, dynamic>?;
    if (memory == null) return null;
    return memory['value'] as String?;
  }

  /// Get all memories
  Future<Map<String, dynamic>> getAllMemories() async {
    final config = await _loadConfig();
    final memories = (config['memories'] as Map<String, dynamic>?) ?? {};
    return Map<String, dynamic>.from(memories);
  }

  /// Delete a memory item
  /// Returns true if the memory existed and was deleted, false if it didn't exist
  Future<bool> deleteMemory(String key) async {
    logService.info(_tag, 'Deleting memory: $key');
    final config = await _loadConfig();
    final memories = (config['memories'] as Map<String, dynamic>?) ?? {};
    final existed = memories.containsKey(key);
    if (existed) {
      memories.remove(key);
      config['memories'] = memories;
      await _saveConfig(config);
    }
    return existed;
  }

  /// Delete all memories
  Future<void> deleteAllMemories() async {
    logService.info(_tag, 'Deleting all memories');
    final config = await _loadConfig();
    config['memories'] = <String, dynamic>{};
    await _saveConfig(config);
  }

  // Android Audio Configuration
  
  /// Save Android audio configuration
  Future<void> saveAndroidAudioConfig(AndroidAudioConfig audioConfig) async {
    logService.info(_tag, 'Saving Android audio config');
    final config = await _loadConfig();
    config['android_audio_config'] = audioConfig.toJson();
    await _saveConfig(config);
  }

  /// Get Android audio configuration
  Future<AndroidAudioConfig> getAndroidAudioConfig() async {
    final config = await _loadConfig();
    final audioConfigJson = config['android_audio_config'] as Map<String, dynamic>?;
    if (audioConfigJson != null) {
      return AndroidAudioConfig.fromJson(audioConfigJson);
    }
    return const AndroidAudioConfig();
  }

  // Call Sessions

  /// Save a call session
  Future<void> saveCallSession(CallSession session) async {
    logService.info(_tag, 'Saving call session: ${session.id}');
    final config = await _loadConfig();
    final sessions = (config['call_sessions'] as List<dynamic>?) ?? [];
    
    // Remove existing session with same ID if it exists
    sessions.removeWhere((s) => (s as Map<String, dynamic>)['id'] == session.id);
    
    // Add new session at the beginning (most recent first)
    sessions.insert(0, session.toJson());
    
    // Keep only last 100 sessions
    if (sessions.length > 100) {
      sessions.removeRange(100, sessions.length);
    }
    
    config['call_sessions'] = sessions;
    await _saveConfig(config);
  }

  /// Get all call sessions
  Future<List<CallSession>> getCallSessions() async {
    final config = await _loadConfig();
    final sessions = (config['call_sessions'] as List<dynamic>?) ?? [];
    return sessions
        .map((s) => CallSession.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific call session by ID
  Future<CallSession?> getCallSession(String id) async {
    final sessions = await getCallSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a call session
  Future<bool> deleteCallSession(String id) async {
    logService.info(_tag, 'Deleting call session: $id');
    final config = await _loadConfig();
    final sessions = (config['call_sessions'] as List<dynamic>?) ?? [];
    final initialLength = sessions.length;
    sessions.removeWhere((s) => (s as Map<String, dynamic>)['id'] == id);
    
    if (sessions.length < initialLength) {
      config['call_sessions'] = sessions;
      await _saveConfig(config);
      return true;
    }
    return false;
  }

  /// Delete all call sessions
  Future<void> deleteAllCallSessions() async {
    logService.info(_tag, 'Deleting all call sessions');
    final config = await _loadConfig();
    config['call_sessions'] = <dynamic>[];
    await _saveConfig(config);
  }

  // Speed Dials

  /// Save a speed dial
  Future<void> saveSpeedDial(SpeedDial speedDial) async {
    logService.info(_tag, 'Saving speed dial: ${speedDial.id}');
    final config = await _loadConfig();
    final speedDials = (config['speed_dials'] as List<dynamic>?) ?? [];
    
    // Remove existing speed dial with same ID if it exists
    speedDials.removeWhere((s) => (s as Map<String, dynamic>)['id'] == speedDial.id);
    
    // Add new speed dial
    speedDials.add(speedDial.toJson());
    
    config['speed_dials'] = speedDials;
    await _saveConfig(config);
  }

  /// Get all speed dials
  Future<List<SpeedDial>> getSpeedDials() async {
    final config = await _loadConfig();
    final speedDials = (config['speed_dials'] as List<dynamic>?) ?? [];
    return speedDials
        .map((s) => SpeedDial.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific speed dial by ID
  Future<SpeedDial?> getSpeedDial(String id) async {
    final speedDials = await getSpeedDials();
    try {
      return speedDials.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a speed dial
  Future<bool> deleteSpeedDial(String id) async {
    logService.info(_tag, 'Deleting speed dial: $id');
    final config = await _loadConfig();
    final speedDials = (config['speed_dials'] as List<dynamic>?) ?? [];
    final initialLength = speedDials.length;
    speedDials.removeWhere((s) => (s as Map<String, dynamic>)['id'] == id);
    
    if (speedDials.length < initialLength) {
      config['speed_dials'] = speedDials;
      await _saveConfig(config);
      return true;
    }
    return false;
  }

  /// Delete all speed dials
  Future<void> deleteAllSpeedDials() async {
    logService.info(_tag, 'Deleting all speed dials');
    final config = await _loadConfig();
    config['speed_dials'] = <dynamic>[];
    await _saveConfig(config);
  }
}
