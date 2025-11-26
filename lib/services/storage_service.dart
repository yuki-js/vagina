import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'log_service.dart';

/// Service for storing settings as files in external storage
class StorageService {
  static const _configFileName = 'vagina_config.json';
  static const _tag = 'Storage';
  
  File? _configFile;

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    logService.info(_tag, 'Requesting storage permission');
    
    // On Android 11+ (API 30+), we need to use MANAGE_EXTERNAL_STORAGE for external access
    // But for Documents directory, we can use the standard storage permission
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      logService.info(_tag, 'Storage permission status: $status');
      
      if (status.isGranted) {
        return true;
      }
      
      // Try manage external storage for Android 11+
      final manageStatus = await Permission.manageExternalStorage.request();
      logService.info(_tag, 'Manage external storage permission status: $manageStatus');
      return manageStatus.isGranted;
    }
    
    return true;
  }

  /// Initialize the storage service by getting the config file path
  Future<File> _getConfigFile() async {
    if (_configFile != null) return _configFile!;
    
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Try to use external storage Documents directory
      final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
      if (externalDirs != null && externalDirs.isNotEmpty) {
        // Get the root external storage path (remove Android/data/package part)
        final externalPath = externalDirs.first.path;
        final parts = externalPath.split('/Android/');
        if (parts.isNotEmpty) {
          directory = Directory('${parts[0]}/Documents/VAGINA');
        }
      }
    }
    
    // Fallback to app documents directory if external storage not available
    directory ??= await getApplicationDocumentsDirectory();
    
    // Create directory if it doesn't exist
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      logService.info(_tag, 'Created directory: ${directory.path}');
    }
    
    _configFile = File('${directory.path}/$_configFileName');
    logService.info(_tag, 'Config file path: ${_configFile!.path}');
    return _configFile!;
  }

  /// Load all settings from file
  Future<Map<String, dynamic>> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        logService.debug(_tag, 'Loaded config from file');
        return jsonDecode(contents) as Map<String, dynamic>;
      }
      logService.debug(_tag, 'Config file does not exist yet');
    } catch (e) {
      logService.error(_tag, 'Failed to load config: $e');
    }
    return {};
  }

  /// Save all settings to file
  Future<void> _saveConfig(Map<String, dynamic> config) async {
    try {
      final file = await _getConfigFile();
      await file.writeAsString(jsonEncode(config));
      logService.info(_tag, 'Saved config to file');
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
    try {
      final uri = Uri.parse(url);
      
      // Expected format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
      if (!uri.host.endsWith('.openai.azure.com')) {
        return null;
      }
      
      final deployment = uri.queryParameters['deployment'];
      final apiVersion = uri.queryParameters['api-version'];
      
      if (deployment == null || deployment.isEmpty) {
        return null;
      }
      
      // Build the endpoint (base URL without path/query)
      final endpoint = '${uri.scheme}://${uri.host}';
      
      return {
        'endpoint': endpoint,
        'deployment': deployment,
        'apiVersion': apiVersion ?? '2024-10-01-preview',
      };
    } catch (e) {
      return null;
    }
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
    final file = await _getConfigFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Get current config file path for display
  Future<String> getConfigFilePath() async {
    final file = await _getConfigFile();
    return file.path;
  }
}
