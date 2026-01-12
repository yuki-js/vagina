import '../models/android_audio_config.dart';
import '../interfaces/config_repository.dart';
import '../interfaces/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of ConfigRepository
class JsonConfigRepository implements ConfigRepository {
  static const _tag = 'ConfigRepo';
  
  // Config keys
  static const _apiKeyKey = 'api_key';
  static const _realtimeUrlKey = 'realtime_url';
  static const _androidAudioConfigKey = 'android_audio_config';
  static const _toolsKey = 'tools';
  
  final KeyValueStore _store;
  final LogService _logService;

  JsonConfigRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  // Azure OpenAI Configuration
  
  @override
  Future<void> saveApiKey(String apiKey) async {
    _logService.debug(_tag, 'Saving API key');
    await _store.set(_apiKeyKey, apiKey);
  }

  @override
  Future<String?> getApiKey() async {
    return await _store.get(_apiKeyKey) as String?;
  }

  @override
  Future<void> deleteApiKey() async {
    _logService.debug(_tag, 'Deleting API key');
    await _store.delete(_apiKeyKey);
  }

  @override
  Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  @override
  Future<void> saveRealtimeUrl(String url) async {
    _logService.debug(_tag, 'Saving realtime URL');
    await _store.set(_realtimeUrlKey, url);
  }

  @override
  Future<String?> getRealtimeUrl() async {
    return await _store.get(_realtimeUrlKey) as String?;
  }

  @override
  Future<void> deleteRealtimeUrl() async {
    _logService.debug(_tag, 'Deleting realtime URL');
    await _store.delete(_realtimeUrlKey);
  }

  @override
  Future<bool> hasAzureConfig() async {
    final hasKey = await hasApiKey();
    final url = await getRealtimeUrl();
    return hasKey && url != null && url.isNotEmpty;
  }

  // Android Audio Configuration
  
  @override
  Future<void> saveAndroidAudioConfig(AndroidAudioConfig config) async {
    _logService.debug(_tag, 'Saving Android audio config');
    await _store.set(_androidAudioConfigKey, config.toJson());
  }

  @override
  Future<AndroidAudioConfig> getAndroidAudioConfig() async {
    final data = await _store.get(_androidAudioConfigKey);
    
    if (data == null) {
      return const AndroidAudioConfig();
    }
    
    return AndroidAudioConfig.fromJson(data as Map<String, dynamic>);
  }

  // Tool Configuration
  
  @override
  Future<bool> isToolEnabled(String toolName) async {
    final tools = await _getToolsConfig();
    return tools[toolName] ?? true; // Default to enabled
  }

  @override
  Future<void> toggleTool(String toolName) async {
    _logService.debug(_tag, 'Toggling tool: $toolName');
    
    final tools = await _getToolsConfig();
    final isCurrentlyEnabled = tools[toolName] ?? true;
    tools[toolName] = !isCurrentlyEnabled;
    
    await _store.set(_toolsKey, tools);
    _logService.info(_tag, 'Tool $toolName ${!isCurrentlyEnabled ? "enabled" : "disabled"}');
  }

  @override
  Future<List<String>> getEnabledTools() async {
    final tools = await _getToolsConfig();
    return tools.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();
  }

  @override
  Future<List<String>> getDisabledTools() async {
    final tools = await _getToolsConfig();
    return tools.entries
        .where((e) => e.value == false)
        .map((e) => e.key)
        .toList();
  }

  Future<Map<String, bool>> _getToolsConfig() async {
    final data = await _store.get(_toolsKey);
    
    if (data == null) {
      return {};
    }
    
    if (data is! Map) {
      return {};
    }
    
    return Map<String, bool>.from(data);
  }

  // General
  
  @override
  Future<void> clearAll() async {
    _logService.info(_tag, 'Clearing all configuration');
    await _store.clear();
  }

  @override
  Future<String> getConfigFilePath() async {
    return await _store.getFilePath();
  }
}
