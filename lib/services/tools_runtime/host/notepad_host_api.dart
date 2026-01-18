import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/services/notepad_service.dart';

/// Host-side adapter for handling notepad API calls from the isolate sandbox
///
/// Routes hostCall messages from the isolate to appropriate NotepadService
/// methods and converts responses to sendable Maps
class NotepadHostApi {
  final NotepadService _notepadService;

  NotepadHostApi(this._notepadService);

  /// Handle API calls from the isolate
  ///
  /// Routes to appropriate NotepadService methods based on [method] parameter
  /// and returns serializable response Maps
  Future<Map<String, dynamic>> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (method) {
        case 'listTabs':
          return await _handleListTabs();
        case 'getTab':
          return await _handleGetTab(args);
        case 'createTab':
          return await _handleCreateTab(args);
        case 'updateTab':
          return await _handleUpdateTab(args);
        case 'closeTab':
          return await _handleCloseTab(args);
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

  Future<Map<String, dynamic>> _handleListTabs() async {
    final tabs = _notepadService.listTabs();
    return {
      'success': true,
      'data': tabs,
    };
  }

  Future<Map<String, dynamic>> _handleGetTab(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: id',
      };
    }

    final tab = _notepadService.getTab(id);
    if (tab == null) {
      return {
        'success': true,
        'data': null,
      };
    }

    return {
      'success': true,
      'data': _tabToMap(tab),
    };
  }

  Future<Map<String, dynamic>> _handleCreateTab(
    Map<String, dynamic> args,
  ) async {
    final content = args['content'] as String?;
    final mimeType = args['mimeType'] as String?;
    final title = args['title'] as String?;

    if (content == null || mimeType == null) {
      return {
        'success': false,
        'error': 'Missing required parameters: content, mimeType',
      };
    }

    final id = _notepadService.createTab(
      content: content,
      mimeType: mimeType,
      title: title,
    );

    return {
      'success': true,
      'data': {'id': id},
    };
  }

  Future<Map<String, dynamic>> _handleUpdateTab(
    Map<String, dynamic> args,
  ) async {
    final id = args['id'] as String?;
    if (id == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: id',
      };
    }

    final content = args['content'] as String?;
    final title = args['title'] as String?;
    final mimeType = args['mimeType'] as String?;

    final success = _notepadService.updateTab(
      id,
      content: content,
      title: title,
      mimeType: mimeType,
    );

    return {
      'success': success,
      'data': {'updated': success},
    };
  }

  Future<Map<String, dynamic>> _handleCloseTab(
    Map<String, dynamic> args,
  ) async {
    final id = args['id'] as String?;
    if (id == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: id',
      };
    }

    final success = _notepadService.closeTab(id);
    return {
      'success': success,
      'data': {'closed': success},
    };
  }

  /// Convert a NotepadTab object to a sendable Map
  Map<String, dynamic> _tabToMap(NotepadTab tab) {
    return {
      'id': tab.id,
      'title': tab.title,
      'mimeType': tab.mimeType,
      'createdAt': tab.createdAt.toIso8601String(),
      'updatedAt': tab.updatedAt.toIso8601String(),
      'contentLength': tab.content.length,
    };
  }
}
