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
  /// and returns serializable response Maps
  Future<Map<String, dynamic>> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
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
          return {
            'success': false,
            'error': 'Unknown method: $method',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleSave(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    final value = args['value'] as String?;

    if (key == null || value == null) {
      return {
        'success': false,
        'error': 'Missing required parameters: key, value',
      };
    }

    await _memoryRepository.save(key, value);
    return {
      'success': true,
      'data': {'saved': true},
    };
  }

  Future<Map<String, dynamic>> _handleRecall(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: key',
      };
    }

    final value = await _memoryRepository.get(key);
    return {
      'success': true,
      'data': value,
    };
  }

  Future<Map<String, dynamic>> _handleDelete(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: key',
      };
    }

    final deleted = await _memoryRepository.delete(key);
    return {
      'success': deleted,
      'data': {'deleted': deleted},
    };
  }

  Future<Map<String, dynamic>> _handleList() async {
    final memories = await _memoryRepository.getAll();
    return {
      'success': true,
      'data': memories,
    };
  }
}
