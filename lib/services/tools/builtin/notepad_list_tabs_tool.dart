import 'package:flutter/material.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';
import 'package:vagina/services/notepad_service.dart';

/// ノートパッドタブ一覧ツール
class NotepadListTabsTool extends BaseTool {
  final NotepadService _notepadService;
  
  NotepadListTabsTool({required NotepadService notepadService}) 
      : _notepadService = notepadService;
  
  @override
  String get name => 'notepad_list_tabs';
  
  @override
  String get description => 
      'List all currently open artifact tabs. Returns metadata for each tab including id, title, mime type, and timestamps.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };
  
  @override
  ToolMetadata get metadata => const ToolMetadata(
    name: 'notepad_list_tabs',
    displayName: 'ノートパッド一覧',
    displayDescription: 'ノートパッドのタブ一覧を取得します',
    description: 'List all currently open artifact tabs.',
    icon: Icons.list,
    category: ToolCategory.notepad,
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabs = _notepadService.listTabs();
    return {
      'success': true,
      'tabs': tabs,
      'count': tabs.length,
    };
  }
}
