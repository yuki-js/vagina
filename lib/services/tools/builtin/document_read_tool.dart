import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for reading a document's content
class DocumentReadTool extends BaseTool {
  final ArtifactService _artifactService;
  
  DocumentReadTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'document_read';
  
  @override
  String get description => 
      'Read the content of a document from an artifact tab. This returns the current content which may include modifications made by the user.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'ID of the tab containing the document to read',
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
      'tabId': tabId,
      'content': tab.content,
      'mime': tab.mimeType,
      'title': tab.title,
    };
  }
}
