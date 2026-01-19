import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';

/// JSON-based implementation of TextAgentRepository
class JsonTextAgentRepository implements TextAgentRepository {
  static const _tag = 'TextAgentRepo';
  static const _textAgentsKey = 'text_agents';
  static const _selectedAgentIdKey = 'selected_text_agent_id';

  final KeyValueStore _store;
  final LogService _logService;

  JsonTextAgentRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> save(TextAgent agent) async {
    _logService.debug(_tag, 'Saving text agent: ${agent.id}');

    final agents = await getAll();

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
  Future<List<TextAgent>> getAll() async {
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
  Future<TextAgent?> getById(String id) async {
    final agents = await getAll();
    try {
      return agents.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String id) async {
    _logService.debug(_tag, 'Deleting text agent: $id');

    final agents = await getAll();
    final initialLength = agents.length;
    agents.removeWhere((a) => a.id == id);

    if (agents.length == initialLength) {
      _logService.warn(_tag, 'Text agent not found: $id');
      return;
    }

    final agentsJson = agents.map((a) => a.toJson()).toList();
    await _store.set(_textAgentsKey, agentsJson);

    // Clear selection if the deleted agent was selected
    final selectedId = await getSelectedAgentId();
    if (selectedId == id) {
      await setSelectedAgentId(null);
    }

    _logService.info(_tag, 'Text agent deleted: $id');
  }

  @override
  Future<String?> getSelectedAgentId() async {
    final data = await _store.get(_selectedAgentIdKey);
    return data as String?;
  }

  @override
  Future<void> setSelectedAgentId(String? id) async {
    if (id == null) {
      await _store.delete(_selectedAgentIdKey);
      _logService.debug(_tag, 'Selected agent ID cleared');
    } else {
      await _store.set(_selectedAgentIdKey, id);
      _logService.debug(_tag, 'Selected agent ID set: $id');
    }
  }
}
