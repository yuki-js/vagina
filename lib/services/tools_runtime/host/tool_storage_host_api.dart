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

  /// Resolve storage namespace for a given tool key.
  ///
  /// Provided by the runtime as the Single Source of Truth (SSoT) for tool
  /// metadata, to avoid maintaining an additional cache here.
  final String Function(String toolKey) _resolveStorageNamespace;

  ToolStorageHostApi(
    this._toolStorage,
    this._getCurrentToolKey, {
    required String Function(String toolKey) resolveStorageNamespace,
    LogService? logService,
  })  : _resolveStorageNamespace = resolveStorageNamespace,
        _logService = logService ?? LogService();

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

    final storageNamespace = _resolveStorageNamespace(toolKey);
    _logService.info(_tag, 'Saving tool $toolKey key=$key, value=$value');
    await _toolStorage.save(storageNamespace, key, value);
    _logService.info(_tag, 'Saved successfully for tool $toolKey key=$key');

    // Return raw value; the runtime wraps hostCall responses.
    return null;
  }

  Future<dynamic> _handleGet(String toolKey, Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    final storageNamespace = _resolveStorageNamespace(toolKey);
    _logService.info(_tag, 'Getting tool $toolKey key=$key');
    final value = await _toolStorage.get(storageNamespace, key);
    _logService.info(_tag, 'Got value for tool $toolKey key=$key: $value');

    return value;
  }

  Future<dynamic> _handleList(String toolKey) async {
    final storageNamespace = _resolveStorageNamespace(toolKey);
    _logService.info(_tag, 'Listing all for tool $toolKey');
    final data = await _toolStorage.listAll(storageNamespace);
    _logService.info(_tag, 'Listed ${data.length} entries for tool $toolKey');

    return data;
  }

  Future<dynamic> _handleDelete(String toolKey, Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    if (key == null) {
      throw Exception('Missing required parameter: key');
    }

    final storageNamespace = _resolveStorageNamespace(toolKey);
    _logService.info(_tag, 'Deleting tool $toolKey key=$key');
    final result = await _toolStorage.delete(storageNamespace, key);
    _logService.info(_tag, 'Delete result for tool $toolKey key=$key: $result');

    return result;
  }

  Future<dynamic> _handleDeleteAll(String toolKey) async {
    final storageNamespace = _resolveStorageNamespace(toolKey);
    _logService.info(_tag, 'Deleting all for tool $toolKey');
    await _toolStorage.deleteAll(storageNamespace);
    _logService.info(_tag, 'Deleted all for tool $toolKey');

    // Return raw value; the runtime wraps hostCall responses.
    return null;
  }
}
