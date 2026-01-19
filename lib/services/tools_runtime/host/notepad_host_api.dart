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
  /// and throws on error
  Future<dynamic> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
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
        throw Exception('Unknown method: $method');
    }
  }

  Future<dynamic> _handleListTabs() async {
    return _notepadService.listTabs();
  }

  Future<dynamic> _handleGetTab(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) {
      throw Exception('Missing required parameter: id');
    }

    final tab = _notepadService.getTab(id);
    if (tab == null) {
      return null;
    }

    return _tabToMapWithContent(tab);
  }

  Future<dynamic> _handleCreateTab(
    Map<String, dynamic> args,
  ) async {
    final content = args['content'] as String?;
    final mimeType = args['mimeType'] as String?;
    final title = args['title'] as String?;

    if (content == null || mimeType == null) {
      throw Exception('Missing required parameters: content, mimeType');
    }

    return _notepadService.createTab(
      content: content,
      mimeType: mimeType,
      title: title,
    );
  }

  Future<dynamic> _handleUpdateTab(
    Map<String, dynamic> args,
  ) async {
    final id = args['id'] as String?;
    if (id == null) {
      throw Exception('Missing required parameter: id');
    }

    final content = args['content'] as String?;
    final title = args['title'] as String?;
    final mimeType = args['mimeType'] as String?;

    return _notepadService.updateTab(
      id,
      content: content,
      title: title,
      mimeType: mimeType,
    );
  }

  Future<dynamic> _handleCloseTab(
    Map<String, dynamic> args,
  ) async {
    final id = args['id'] as String?;
    if (id == null) {
      throw Exception('Missing required parameter: id');
    }

    return _notepadService.closeTab(id);
  }

  /// Convert a NotepadTab object to a sendable Map (metadata only, no content)
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

  /// Convert a NotepadTab object to a sendable Map with content included
  Map<String, dynamic> _tabToMapWithContent(NotepadTab tab) {
    return {
      'id': tab.id,
      'title': tab.title,
      'content': tab.content,
      'mimeType': tab.mimeType,
      'createdAt': tab.createdAt.toIso8601String(),
      'updatedAt': tab.updatedAt.toIso8601String(),
      'contentLength': tab.content.length,
    };
  }
}
