import 'package:flutter/material.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';
import 'package:vagina/services/notepad_service.dart';

/// ノートパッドメタデータ取得ツール
class NotepadGetMetadataTool extends BaseTool {
  final NotepadService _notepadService;
  
  NotepadGetMetadataTool({required NotepadService notepadService}) 
      : _notepadService = notepadService;
  
  @override
  String get name => 'notepad_get_metadata';
  
  @override
  String get description => 
      'Get metadata of a specific artifact tab by its ID. Returns id, title, mime type, timestamps, and content length.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'The unique identifier of the tab',
      },
    },
    'required': ['tabId'],
  };
  
  @override
  ToolMetadata get metadata => const ToolMetadata(
    name: 'notepad_get_metadata',
    displayName: 'ノートパッド情報',
    displayDescription: 'ノートパッドの詳細情報を取得します',
    description: 'Get metadata of a specific artifact tab by its ID.',
    icon: Icons.info,
    category: ToolCategory.notepad,
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final metadata = _notepadService.getTabMetadata(tabId);
    
    if (metadata == null) {
      return {
        'success': false,
        'error': 'Tab not found: $tabId',
      };
    }
    
    return {
      'success': true,
      'metadata': metadata,
    };
  }
}
