import 'package:flutter/material.dart';
import '../base_tool.dart';
import '../tool_metadata.dart';
import '../../../interfaces/memory_repository.dart';

/// メモリ保存ツール
class MemorySaveTool extends BaseTool {
  final MemoryRepository _memoryRepo;

  MemorySaveTool({required MemoryRepository memoryRepository})
      : _memoryRepo = memoryRepository;

  @override
  String get name => 'memory_save';

  @override
  String get description =>
      'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.';

  @override
  Map<String, dynamic> get parameters => {
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
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'memory_save',
        displayName: 'メモリ保存',
        displayDescription: '重要な情報を記憶します',
        description:
            'Save information to long-term memory that persists across sessions.',
        icon: Icons.save,
        category: ToolCategory.memory,
      );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    final value = arguments['value'] as String;

    await _memoryRepo.save(key, value);

    return {
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    };
  }
}
