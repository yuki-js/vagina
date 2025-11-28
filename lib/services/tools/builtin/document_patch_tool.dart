import 'package:diff_match_patch/diff_match_patch.dart';
import '../base_tool.dart';
import '../../notepad_service.dart';

/// Tool for patching a document using unified diff format
class DocumentPatchTool extends BaseTool {
  final NotepadService _notepadService;
  
  DocumentPatchTool({required NotepadService notepadService}) 
      : _notepadService = notepadService;
  
  @override
  String get name => 'document_patch';
  
  @override
  String get description => 
      'Apply a unified diff patch to an existing document. Use standard unified diff format (like git diff or diff -u). This is the preferred way to make small changes to existing documents.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'ID of the tab containing the document to patch',
      },
      'patch': {
        'type': 'string',
        'description': 'Unified diff format patch to apply. Lines starting with "-" are removed, lines starting with "+" are added. Context lines (no prefix) help locate the change.',
      },
    },
    'required': ['tabId', 'patch'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String;
    final patchText = arguments['patch'] as String;
    
    final tab = _notepadService.getTab(tabId);
    if (tab == null) {
      return {
        'success': false,
        'error': 'Tab not found: $tabId',
      };
    }
    
    final originalContent = tab.content;
    
    // Parse the patch
    List<Patch> patches;
    try {
      patches = patchFromText(patchText);
    } catch (e) {
      return {
        'success': false,
        'error': 'Invalid patch format: $e. Please use unified diff format.',
      };
    }
    
    if (patches.isEmpty) {
      return {
        'success': false,
        'error': 'No valid patches found in the provided diff.',
      };
    }
    
    // Apply the patch
    final result = patchApply(patches, originalContent);
    final patchedContent = result[0] as String;
    final patchResults = result[1] as List<bool>;
    
    // Check if all patches were applied successfully
    final successCount = patchResults.where((r) => r).length;
    final failCount = patchResults.where((r) => !r).length;
    
    if (failCount > 0 && successCount == 0) {
      return {
        'success': false,
        'error': 'Failed to apply any patches. The document content may have changed since the diff was created.',
        'failedPatches': failCount,
      };
    }
    
    // Update the document
    final updateSuccess = _notepadService.updateTab(tabId, content: patchedContent);
    
    if (!updateSuccess) {
      return {
        'success': false,
        'error': 'Failed to update document after applying patches.',
      };
    }
    
    if (failCount > 0) {
      return {
        'success': true,
        'tabId': tabId,
        'appliedPatches': successCount,
        'failedPatches': failCount,
        'warning': 'Some patches could not be applied. $successCount succeeded, $failCount failed.',
      };
    }
    
    return {
      'success': true,
      'tabId': tabId,
      'appliedPatches': successCount,
      'message': 'All patches applied successfully',
    };
  }
}
