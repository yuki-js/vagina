import '../base_tool.dart';
import '../../artifact_service.dart';

/// Tool for listing all artifact tabs
class ArtifactListTabsTool extends BaseTool {
  final ArtifactService _artifactService;
  
  ArtifactListTabsTool({required ArtifactService artifactService}) 
      : _artifactService = artifactService;
  
  @override
  String get name => 'artifact_list_tabs';
  
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
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabs = _artifactService.listTabs();
    return {
      'success': true,
      'tabs': tabs,
      'count': tabs.length,
    };
  }
}

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
