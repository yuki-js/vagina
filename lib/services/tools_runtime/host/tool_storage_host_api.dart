import 'package:vagina/interfaces/tool_storage.dart';
import 'package:vagina/services/log_service.dart';

/// Host-side adapter for handling tool storage API calls from isolate sandboxes
///
/// Routes hostCall messages from the isolate to appropriate ToolStorage
/// methods, with the toolKey obtained from the execution context callback.
class ToolStorageHostApi {
  static const String _tag = 'ToolStorageHostApi';
  
  final ToolStorage _toolStorage;
  final LogService _logService;
  
  /// Callback to get the currently executing tool key
  /// This is called for each request to ensure we use the correct tool context
  final String Function() _getCurrentToolKey;

  ToolStorageHostApi(
    this._toolStorage,
    this._getCurrentToolKey, {
    LogService? logService,
  }) : _logService = logService ?? LogService();

  /// Handle API calls from the isolate
  ///
  /// Routes to appropriate ToolStorage methods based on [method] parameter
  /// and throws on error. The current tool key is obtained from context.
  Future<dynamic> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    final toolKey = _getCurrentToolKey();
    _logService.debug(_tag, 'hostCall: $method for tool $toolKey, args: $args');
    
    try {
      switch (method) {
        case 'save':
          return await _handleSave(toolKey, args);
        case 'get':
          return await _handleGet(toolKey, args);
        case 'list':
          return await _handleList(toolKey);
        case 'delete':
          return await _handleDelete(toolKey, args);
        case 'deleteAll':
          return await _handleDeleteAll(toolKey);
        default:
          throw Exception('Unknown method: $method');
      }
    } catch (e) {
      _logService.error(_tag, 'Error in $method: $e');
      rethrow;
    }
  }

  Future<dynamic> _handleSave(String toolKey, Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    final value = args['value'];

    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    _logService.info(_tag, 'Saving tool $toolKey key=$key, value=$value');
    await _toolStorage.save(toolKey, key, value);
    _logService.info(_tag, 'Saved successfully for tool $toolKey key=$key');
    
    // Return success response structure for the API client
    return {
      'status': 'success',
      'data': null,
    };
  }

  Future<dynamic> _handleGet(String toolKey, Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    _logService.info(_tag, 'Getting tool $toolKey key=$key');
    final value = await _toolStorage.get(toolKey, key);
    _logService.info(_tag, 'Got value for tool $toolKey key=$key: $value');
    
    return {
      'status': 'success',
      'data': value,
    };
  }

  Future<dynamic> _handleList(String toolKey) async {
    _logService.info(_tag, 'Listing all for tool $toolKey');
    final data = await _toolStorage.listAll(toolKey);
    _logService.info(_tag, 'Listed ${data.length} entries for tool $toolKey');
    
    return {
      'status': 'success',
      'data': data,
    };
  }

  Future<dynamic> _handleDelete(String toolKey, Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    _logService.info(_tag, 'Deleting tool $toolKey key=$key');
    final result = await _toolStorage.delete(toolKey, key);
    _logService.info(_tag, 'Delete result for tool $toolKey key=$key: $result');
    
    return {
      'status': 'success',
      'data': result,
    };
  }

  Future<dynamic> _handleDeleteAll(String toolKey) async {
    _logService.info(_tag, 'Deleting all for tool $toolKey');
    await _toolStorage.deleteAll(toolKey);
    _logService.info(_tag, 'Deleted all for tool $toolKey');
    
    return {
      'status': 'success',
      'data': null,
    };
  }
}
