import 'package:vagina/models/android_audio_config.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';

/// JSON-based implementation of ConfigRepository
class JsonConfigRepository implements ConfigRepository {
  static const _tag = 'ConfigRepo';

  // Config keys
  static const _apiKeyKey = 'api_key';
  static const _realtimeUrlKey = 'realtime_url';
  static const _androidAudioConfigKey = 'android_audio_config';
  static const _toolsKey = 'tools';
  static const _textAgentsKey = 'text_agents';
  static const _selectedTextAgentIdKey = 'selected_text_agent_id';

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
  Future<void> enableTool(String toolKey) async {
    await _store.set(_toolsKey, {
      ...await _getToolsConfig(),
      toolKey: true,
    });
  }

  @override
  Future<void> disableTool(String toolKey) async {
    await _store.set(_toolsKey, {
      ...await _getToolsConfig(),
      toolKey: false,
    });
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

  // Text Agent Configuration

  @override
  Future<void> saveTextAgent(TextAgent agent) async {
    _logService.debug(_tag, 'Saving text agent: ${agent.id}');

    final agents = await getAllTextAgents();

    // Check if agent already exists
    final existingIndex = agents.indexWhere((a) => a.id == agent.id);
    if (existingIndex != -1) {
      // Update existing agent
      agents[existingIndex] = agent;
    } else {
      // Add new agent
      agents.add(agent);
    }

    final agentsJson = agents.map((a) => a.toJson()).toList();
    await _store.set(_textAgentsKey, agentsJson);

    _logService.info(_tag, 'Text agent saved: ${agent.id}');
  }

  @override
  Future<List<TextAgent>> getAllTextAgents() async {
    final data = await _store.get(_textAgentsKey);

    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logService.warn(_tag, 'Invalid text agents data type');
      }
      return [];
    }

    try {
      return data
          .map((json) => TextAgent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logService.error(_tag, 'Error parsing text agents: $e');
      return [];
    }
  }

  @override
  Future<TextAgent?> getTextAgentById(String id) async {
    final agents = await getAllTextAgents();
    try {
      return agents.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteTextAgent(String id) async {
    _logService.debug(_tag, 'Deleting text agent: $id');

    final agents = await getAllTextAgents();
    final initialLength = agents.length;
    agents.removeWhere((a) => a.id == id);

    if (agents.length == initialLength) {
      _logService.warn(_tag, 'Text agent not found: $id');
      return;
    }

    final agentsJson = agents.map((a) => a.toJson()).toList();
    await _store.set(_textAgentsKey, agentsJson);

    // Clear selection if the deleted agent was selected
    final selectedId = await getSelectedTextAgentId();
    if (selectedId == id) {
      await setSelectedTextAgentId(null);
    }

    _logService.info(_tag, 'Text agent deleted: $id');
  }

  @override
  Future<String?> getSelectedTextAgentId() async {
    final data = await _store.get(_selectedTextAgentIdKey);
    return data as String?;
  }

  @override
  Future<void> setSelectedTextAgentId(String? id) async {
    if (id == null) {
      await _store.delete(_selectedTextAgentIdKey);
      _logService.debug(_tag, 'Selected text agent ID cleared');
    } else {
      await _store.set(_selectedTextAgentIdKey, id);
      _logService.debug(_tag, 'Selected text agent ID set: $id');
    }
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
