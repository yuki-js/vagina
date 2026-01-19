import 'package:vagina/interfaces/memory_repository.dart';

/// Host-side adapter for handling memory API calls from the isolate sandbox
///
/// Routes hostCall messages from the isolate to appropriate MemoryRepository
/// methods and converts responses to sendable Maps
class MemoryHostApi {
  final MemoryRepository _memoryRepository;

  MemoryHostApi(this._memoryRepository);

  /// Handle API calls from the isolate
  ///
  /// Routes to appropriate MemoryRepository methods based on [method] parameter
  /// and throws on error
  Future<dynamic> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'save':
        return await _handleSave(args);
      case 'recall':
        return await _handleRecall(args);
      case 'delete':
        return await _handleDelete(args);
      case 'list':
        return await _handleList();
      default:
        throw Exception('Unknown method: $method');
    }
  }

  Future<dynamic> _handleSave(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    final value = args['value'] as String?;

    if (key == null || value == null) {
      throw Exception('Missing required parameters: key, value');
    }

    await _memoryRepository.save(key, value);
    return null;
  }

  Future<dynamic> _handleRecall(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    return await _memoryRepository.get(key);
  }

  Future<dynamic> _handleDelete(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    return await _memoryRepository.delete(key);
  }

  Future<dynamic> _handleList() async {
    return await _memoryRepository.getAll();
  }
}
