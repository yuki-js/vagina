import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for closing an artifact tab
class ArtifactCloseTabTool extends BaseTool {
  final ArtifactService _artifactService;
  
  ArtifactCloseTabTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'artifact_close_tab';
  
  @override
  String get description => 
      'Close an artifact tab by its ID.';
  
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
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final success = _artifactService.closeTab(tabId);
    
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
