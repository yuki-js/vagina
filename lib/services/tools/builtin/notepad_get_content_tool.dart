import '../base_tool.dart';
import '../../notepad_service.dart';

/// Tool for getting content of a specific artifact tab
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
