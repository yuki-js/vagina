import 'package:flutter/material.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';
import 'package:vagina/services/notepad_service.dart';

/// ノートパッドコンテンツ取得ツール
class NotepadGetContentTool extends BaseTool {
  final NotepadService _notepadService;
  
  NotepadGetContentTool({required NotepadService notepadService}) 
      : _notepadService = notepadService;
  
  @override
  String get name => 'notepad_get_content';
  
  @override
  String get description => 
      'Get the content of a specific artifact tab by its ID.';
  
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
    name: 'notepad_get_content',
    displayName: 'ノートパッド読取',
    displayDescription: 'ノートパッドの内容を読み取ります',
    description: 'Get the content of a specific artifact tab by its ID.',
    icon: Icons.article,
    category: ToolCategory.notepad,
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final tab = _notepadService.getTab(tabId);
    
    if (tab == null) {
      return {
        'success': false,
        'error': 'Tab not found: $tabId',
      };
    }
    
    return {
      'success': true,
      'content': tab.content,
      'mimeType': tab.mimeType,
    };
  }
}
