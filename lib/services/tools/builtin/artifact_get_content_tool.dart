import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for getting content of a specific artifact tab
class ArtifactGetContentTool extends BaseTool {
  final ArtifactService _artifactService;
  
  ArtifactGetContentTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'artifact_get_content';
  
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
    final tab = _artifactService.getTab(tabId);
    
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
