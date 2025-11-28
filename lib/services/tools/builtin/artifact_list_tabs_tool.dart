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
