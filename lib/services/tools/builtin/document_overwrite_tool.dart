import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for creating or overwriting a document
class DocumentOverwriteTool extends BaseTool {
  final ArtifactService _artifactService;
  
  DocumentOverwriteTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'document_overwrite';
  
  @override
  String get description => 
      'Create a new document or overwrite an existing one. If tabId is not provided, creates a new tab. If tabId is provided, replaces the content of that tab. Use this for creating and fully replacing documents.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'Optional: ID of an existing tab to overwrite. If not provided, creates a new tab.',
      },
      'content': {
        'type': 'string',
        'description': 'The content of the document',
      },
      'mime': {
        'type': 'string',
        'description': 'MIME type of the content (e.g., "text/markdown", "text/plain", "text/html"). Defaults to "text/markdown".',
      },
      'title': {
        'type': 'string',
        'description': 'Optional title for the document. If not provided, will be auto-generated from content.',
      },
    },
    'required': ['content'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String?;
    final content = arguments['content'] as String;
    final mime = (arguments['mime'] as String?) ?? 'text/markdown';
    final title = arguments['title'] as String?;
    
    if (tabId != null) {
      // Update existing tab
      final success = _artifactService.updateTab(
        tabId, 
        content: content, 
        title: title,
        mimeType: mime,
      );
      
      if (!success) {
        return {
          'success': false,
          'error': 'Tab not found: $tabId. Please create a new document without specifying tabId.',
        };
      }
      
      return {
        'success': true,
        'tabId': tabId,
        'message': 'Document updated successfully',
      };
    } else {
      // Create new tab
      final newTabId = _artifactService.createTab(
        content: content,
        mimeType: mime,
        title: title,
      );
      
      return {
        'success': true,
        'tabId': newTabId,
        'message': 'Document created successfully',
      };
    }
  }
}
