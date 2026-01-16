import 'package:flutter/material.dart';
import '../base_tool.dart';
import '../tool_metadata.dart';
import '../../notepad_service.dart';

/// ノートパッドタブクローズツール
class NotepadCloseTabTool extends BaseTool {
  final NotepadService _notepadService;

  NotepadCloseTabTool({required NotepadService notepadService})
      : _notepadService = notepadService;

  @override
  String get name => 'notepad_close_tab';

  @override
  String get description => 'Close an artifact tab by its ID.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'tabId': {
            'type': 'string',
            'description': 'The unique identifier of the tab to close',
          },
        },
        'required': ['tabId'],
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'notepad_close_tab',
        displayName: 'ノートパッド閉じる',
        displayDescription: 'ノートパッドのタブを閉じます',
        description: 'Close an artifact tab by its ID.',
        icon: Icons.close,
        category: ToolCategory.notepad,
      );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final success = _notepadService.closeTab(tabId);

    if (!success) {
      return {
        'success': false,
        'error': 'Tab not found: $tabId',
      };
    }

    return {
      'success': true,
      'message': 'Tab closed successfully',
    };
  }
}
