import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'calculator_tool.dart';
import 'document_overwrite_tool.dart';
import 'document_patch_tool.dart';
import 'document_read_tool.dart';
import 'get_current_time_tool.dart';
import 'memory_delete_tool.dart';
import 'memory_recall_tool.dart';
import 'memory_save_tool.dart';
import 'notepad_close_tab_tool.dart';
import 'notepad_get_content_tool.dart';
import 'notepad_get_metadata_tool.dart';
import 'notepad_list_tabs_tool.dart';

/// Builtin tool catalog for listing definitions and creating tool instances.
///
/// This is a pure static class with no instance state, designed to support:
/// 1. Pre-call UI listing of tool definitions (host-side)
/// 2. Tool instantiation inside isolate workers (without closures crossing boundaries)
///
/// The catalog uses a switch-based factory pattern instead of closures,
/// making it safe to use across isolate boundaries.
class BuiltinToolCatalog {
  // Prevent instantiation
  BuiltinToolCatalog._();

  /// Cached list of builtin tool definitions.
  ///
  /// Initialized lazily on first call to [listDefinitions].
  static List<ToolDefinition>? _definitionsCache;

  /// Tool definitions for Memory tools that require external dependencies.
  ///
  /// These are created directly without instantiation since Memory tools
  /// require MemoryRepository which is not available in the catalog.
  /// Once ToolContext is refactored to include MemoryRepository,
  /// these can be instantiated normally.
  static const ToolDefinition _memorySaveDefinition = ToolDefinition(
    toolKey: 'memory_save',
    displayName: 'メモリ保存',
    displayDescription: '重要な情報を記憶します',
    categoryKey: 'memory',
    iconKey: 'save',
    sourceKey: 'builtin',
    description:
        'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description':
              'A unique key to identify this memory (e.g., "user_name", "favorite_color")',
        },
        'value': {
          'type': 'string',
          'description': 'The information to remember',
        },
      },
      'required': ['key', 'value'],
    },
  );

  static const ToolDefinition _memoryRecallDefinition = ToolDefinition(
    toolKey: 'memory_recall',
    displayName: 'メモリ検索',
    displayDescription: '記憶した情報を検索します',
    categoryKey: 'memory',
    iconKey: 'search',
    sourceKey: 'builtin',
    description:
        'Recall information from long-term memory. Use this when you need to remember something the user previously asked you to save.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description':
              'The key of the memory to recall. Use "all" to get all stored memories.',
        },
      },
      'required': ['key'],
    },
  );

  static const ToolDefinition _memoryDeleteDefinition = ToolDefinition(
    toolKey: 'memory_delete',
    displayName: 'メモリ削除',
    displayDescription: '記憶した情報を削除します',
    categoryKey: 'memory',
    iconKey: 'delete',
    sourceKey: 'builtin',
    description:
        'Delete information from long-term memory. Use this when the user asks you to forget something.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description':
              'The key of the memory to delete. Use "all" to delete all memories.',
        },
      },
      'required': ['key'],
    },
  );

  /// Returns all builtin tool definitions.
  ///
  /// Used by the host UI for pre-call listing. Does NOT instantiate tools,
  /// only returns their definitions.
  ///
  /// Results are cached after first call for efficiency.
  static List<ToolDefinition> listDefinitions() {
    if (_definitionsCache != null) {
      return _definitionsCache!;
    }

    _definitionsCache = <ToolDefinition>[
      CalculatorTool().definition,
      DocumentOverwriteTool().definition,
      DocumentPatchTool().definition,
      DocumentReadTool().definition,
      GetCurrentTimeTool().definition,
      _memoryDeleteDefinition,
      _memoryRecallDefinition,
      _memorySaveDefinition,
      NotepadCloseTabTool().definition,
      NotepadGetContentTool().definition,
      NotepadGetMetadataTool().definition,
      NotepadListTabsTool().definition,
    ];

    return _definitionsCache!;
  }

  /// Creates a tool instance by toolKey.
  ///
  /// Uses a switch statement (no closures) to instantiate the appropriate tool
  /// with the provided [context]. Safe to call from isolate workers.
  ///
  /// Throws [UnknownToolException] if the toolKey is not recognized.
  ///
  /// Note: Memory tools (memory_save, memory_recall, memory_delete) require
  /// MemoryRepository which is currently not available in ToolContext.
  /// These tools should be created through ToolService instead, which has
  /// access to the repository. This limitation will be resolved in a later
  /// refactoring when ToolContext includes MemoryRepository.
  static Tool createTool(String toolKey, ToolContext context) {
    switch (toolKey) {
      case 'calculator':
        return CalculatorTool();

      case 'document_overwrite':
        return DocumentOverwriteTool();

      case 'document_patch':
        return DocumentPatchTool();

      case 'document_read':
        return DocumentReadTool();

      case 'get_current_time':
        return GetCurrentTimeTool();

      case 'memory_delete':
        throw MemoryToolException(
          toolKey,
          'Memory tools require MemoryRepository which is not available '
          'in ToolContext yet. Use ToolService to create these tools instead. '
          'This limitation will be resolved in a later refactoring.',
        );

      case 'memory_recall':
        throw MemoryToolException(
          toolKey,
          'Memory tools require MemoryRepository which is not available '
          'in ToolContext yet. Use ToolService to create these tools instead. '
          'This limitation will be resolved in a later refactoring.',
        );

      case 'memory_save':
        throw MemoryToolException(
          toolKey,
          'Memory tools require MemoryRepository which is not available '
          'in ToolContext yet. Use ToolService to create these tools instead. '
          'This limitation will be resolved in a later refactoring.',
        );

      case 'notepad_close_tab':
        return NotepadCloseTabTool();

      case 'notepad_get_content':
        return NotepadGetContentTool();

      case 'notepad_get_metadata':
        return NotepadGetMetadataTool();

      case 'notepad_list_tabs':
        return NotepadListTabsTool();

      default:
        throw UnknownToolException(toolKey);
    }
  }
}

/// Exception thrown when an unknown tool key is requested.
class UnknownToolException implements Exception {
  final String toolKey;

  UnknownToolException(this.toolKey);

  @override
  String toString() =>
      'UnknownToolException: Unknown tool key "$toolKey". '
      'Available tools: calculator, document_read, document_overwrite, document_patch, '
      'get_current_time, memory_save, memory_recall, memory_delete, '
      'notepad_list_tabs, notepad_get_metadata, notepad_get_content, notepad_close_tab';
}

/// Exception thrown when a Memory tool cannot be created due to missing dependencies.
///
/// Memory tools require MemoryRepository which is not currently available
/// in ToolContext. They should be created through ToolService instead.
class MemoryToolException implements Exception {
  final String toolKey;
  final String message;

  MemoryToolException(this.toolKey, this.message);

  @override
  String toString() => 'MemoryToolException: Cannot create "$toolKey" tool. $message';
}
