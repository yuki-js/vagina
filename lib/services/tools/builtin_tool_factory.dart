import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import '../storage_service.dart';

/// Factory for creating built-in tools
class BuiltinToolFactory {
  final StorageService _storage;
  
  BuiltinToolFactory({required StorageService storage}) : _storage = storage;
  
  /// Create all built-in tools
  List<BaseTool> createBuiltinTools() {
    return [
      GetCurrentTimeTool(),
      MemorySaveTool(storage: _storage),
      MemoryRecallTool(storage: _storage),
      MemoryDeleteTool(storage: _storage),
      CalculatorTool(),
    ];
  }
}
