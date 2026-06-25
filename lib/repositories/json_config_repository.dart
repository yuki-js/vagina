import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:logging/logging.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';

/// JSON-based implementation of ConfigRepository
class JsonConfigRepository implements ConfigRepository {
  // Config keys
  static const _voiceAgentApiConfigKey = 'voice_agent_api_config';
  static const _textAgentsKey = 'text_agents';

  static final Logger _logger = Logger('JsonConfigRepository');

  final KeyValueStore _store;

  JsonConfigRepository(this._store);

  // Voice agent API configuration

  @override
  Future<void> saveVoiceAgentApiConfig(VoiceAgentApiConfig config) async {
    _logger.fine('Saving voice agent API config: ${config.runtimeType}');
    await _store.set(_voiceAgentApiConfigKey, config.toJson());
  }

  @override
  Future<VoiceAgentApiConfig?> getVoiceAgentApiConfig() async {
    final data = await _store.get(_voiceAgentApiConfigKey);
    if (data == null) {
      return null;
    }

    if (data is! Map) {
      _logger.warning('Invalid voice agent api config data type');
      return null;
    }

    try {
      return VoiceAgentApiConfig.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _logger.severe('Error parsing voice agent api config: $e');
      return null;
    }
  }

  // Text Agent Configuration

  @override
  Future<void> saveTextAgent(TextAgentInfo agent) async {
    _logger.fine('Saving text agent: ${agent.id}');

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

    _logger.info('Text agent saved: ${agent.id}');
  }

  @override
  Future<List<TextAgentInfo>> getAllTextAgents() async {
    final data = await _store.get(_textAgentsKey);

    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logger.warning('Invalid text agents data type');
      }
      return [];
    }

    try {
      return data
          .map((json) => TextAgentInfo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.severe('Error parsing text agents: $e');
      return [];
    }
  }

  @override
  Future<TextAgentInfo?> getTextAgentById(String id) async {
    final agents = await getAllTextAgents();
    try {
      return agents.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteTextAgent(String id) async {
    _logger.fine('Deleting text agent: $id');

    final agents = await getAllTextAgents();
    final initialLength = agents.length;
    agents.removeWhere((a) => a.id == id);

    if (agents.length == initialLength) {
      _logger.warning('Text agent not found: $id');
      return;
    }

    final agentsJson = agents.map((a) => a.toJson()).toList();
    await _store.set(_textAgentsKey, agentsJson);

    _logger.info('Text agent deleted: $id');
  }

  // General

  @override
  Future<void> clearAll() async {
    _logger.info('Clearing all configuration');
    await _store.clear();
  }

  @override
  Future<String> getConfigFilePath() async {
    return await _store.getFilePath();
  }
}
