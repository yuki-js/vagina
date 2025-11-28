import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import '../storage_service.dart';
import '../artifact_service.dart';

/// Factory for creating built-in tools
class BuiltinToolFactory {
  final StorageService _storage;
  final ArtifactService _artifactService;
  
  BuiltinToolFactory({
    required StorageService storage,
    required ArtifactService artifactService,
  }) : _storage = storage, _artifactService = artifactService;
  
  /// Create all built-in tools
  List<BaseTool> createBuiltinTools() {
    return [
      GetCurrentTimeTool(),
      MemorySaveTool(storage: _storage),
      MemoryRecallTool(storage: _storage),
      MemoryDeleteTool(storage: _storage),
      CalculatorTool(),
      // Artifact management tools
      ArtifactListTabsTool(artifactService: _artifactService),
      ArtifactGetMetadataTool(artifactService: _artifactService),
      ArtifactGetContentTool(artifactService: _artifactService),
      ArtifactCloseTabTool(artifactService: _artifactService),
      // Document creation tools
      DocumentOverwriteTool(artifactService: _artifactService),
      DocumentPatchTool(artifactService: _artifactService),
      DocumentReadTool(artifactService: _artifactService),
    ];
  }
}
