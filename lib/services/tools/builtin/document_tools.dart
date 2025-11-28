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
    
    try {
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
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save document: $e',
      };
    }
  }
}

/// Tool for patching a document with a diff
class DocumentPatchTool extends BaseTool {
  final ArtifactService _artifactService;
  
  DocumentPatchTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'document_patch';
  
  @override
  String get description => 
      'Apply a patch to an existing document. The patch should specify the text to find and replace. Use this for making small changes to existing documents instead of rewriting the entire content.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'ID of the tab containing the document to patch',
      },
      'patches': {
        'type': 'array',
        'description': 'Array of patch operations to apply',
        'items': {
          'type': 'object',
          'properties': {
            'find': {
              'type': 'string',
              'description': 'Text to find in the document',
            },
            'replace': {
              'type': 'string',
              'description': 'Text to replace the found text with',
            },
          },
          'required': ['find', 'replace'],
        },
      },
    },
    'required': ['tabId', 'patches'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final patches = arguments['patches'] as List<dynamic>;
    
    try {
      final tab = _artifactService.getTab(tabId);
      if (tab == null) {
        return {
          'success': false,
          'error': 'Tab not found: $tabId',
        };
      }
      
      var content = tab.content;
      final appliedPatches = <Map<String, dynamic>>[];
      final failedPatches = <Map<String, dynamic>>[];
      
      for (final patch in patches) {
        final find = patch['find'] as String;
        final replace = patch['replace'] as String;
        
        if (content.contains(find)) {
          content = content.replaceFirst(find, replace);
          appliedPatches.add({'find': find, 'replace': replace});
        } else {
          failedPatches.add({
            'find': find, 
            'replace': replace,
            'error': 'Text not found in document',
          });
        }
      }
      
      // Only update if at least one patch was applied
      if (appliedPatches.isEmpty) {
        return {
          'success': false,
          'error': 'No patches could be applied. None of the search strings were found in the document.',
          'failedPatches': failedPatches,
        };
      }
      
      _artifactService.updateTab(tabId, content: content);
      
      return {
        'success': true,
        'tabId': tabId,
        'appliedPatches': appliedPatches.length,
        'failedPatches': failedPatches.length,
        'failedPatchDetails': failedPatches.isNotEmpty ? failedPatches : null,
        'message': failedPatches.isEmpty 
            ? 'All patches applied successfully'
            : 'Some patches were applied, but ${failedPatches.length} failed',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to patch document: $e',
      };
    }
  }
}

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
