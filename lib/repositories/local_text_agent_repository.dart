import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../interfaces/text_agent_repository.dart';
import '../models/text_agent.dart';
import '../services/log_service.dart';

/// Local storage implementation of TextAgentRepository
class LocalTextAgentRepository implements TextAgentRepository {
  static const _tag = 'LocalTextAgentRepository';
  static const _fileName = 'text_agents.json';
  
  final LogService _logService;
  
  LocalTextAgentRepository({LogService? logService})
      : _logService = logService ?? LogService();

  Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _fileName);
  }

  Future<File> get _file async {
    final filePath = await _filePath;
    return File(filePath);
  }

  @override
  Future<List<TextAgent>> getAll() async {
    try {
      final file = await _file;
      if (!await file.exists()) {
        _logService.debug(_tag, 'No text agents file found, returning empty list');
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      
      final agents = jsonList
          .map((json) => TextAgent.fromJson(json as Map<String, dynamic>))
          .toList();
      
      _logService.debug(_tag, 'Loaded ${agents.length} text agents from storage');
      return agents;
    } catch (e) {
      _logService.error(_tag, 'Failed to load text agents: $e');
      return [];
    }
  }

  @override
  Future<TextAgent?> getById(String id) async {
    final agents = await getAll();
    try {
      return agents.firstWhere((agent) => agent.id == id);
    } catch (e) {
      _logService.debug(_tag, 'Text agent not found: $id');
      return null;
    }
  }

  @override
  Future<void> save(TextAgent agent) async {
    try {
      final agents = await getAll();
      
      // Remove existing agent with same ID if it exists
      agents.removeWhere((a) => a.id == agent.id);
      
      // Add the new/updated agent
      agents.add(agent);
      
      // Write to file
      final file = await _file;
      final jsonList = agents.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      
      _logService.info(_tag, 'Saved text agent: ${agent.id}');
    } catch (e) {
      _logService.error(_tag, 'Failed to save text agent: $e');
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final agents = await getAll();
      final initialCount = agents.length;
      
      agents.removeWhere((agent) => agent.id == id);
      
      if (agents.length == initialCount) {
        _logService.debug(_tag, 'Text agent not found for deletion: $id');
        return;
      }
      
      final file = await _file;
      final jsonList = agents.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      
      _logService.info(_tag, 'Deleted text agent: $id');
    } catch (e) {
      _logService.error(_tag, 'Failed to delete text agent: $e');
      rethrow;
    }
  }

  @override
  Future<bool> exists(String id) async {
    final agent = await getById(id);
    return agent != null;
  }
}
