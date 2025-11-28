import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for getting metadata of a specific artifact tab
class ArtifactGetMetadataTool extends BaseTool {
  final ArtifactService _artifactService;
  
  ArtifactGetMetadataTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'artifact_get_metadata';
  
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
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final metadata = _artifactService.getTabMetadata(tabId);
    
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
