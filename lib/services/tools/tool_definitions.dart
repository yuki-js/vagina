import '../../models/tool_definition.dart';

/// Tool definitions for built-in tools
class ToolDefinitions {
  static List<ToolDefinition> getBuiltInTools() {
    return [
      // Tool 1: Get current time
      ToolDefinition(
        name: 'get_current_time',
        description: 'Get the current date and time. Use this when the user asks about the current time or date.',
        parameters: {
          'type': 'object',
          'properties': {
            'timezone': {
              'type': 'string',
              'description': 'Timezone name (e.g., "Asia/Tokyo", "UTC"). Defaults to local time if not specified.',
            },
          },
          'required': [],
        },
      ),

      // Tool 2: Memory - Save to long-term storage
      ToolDefinition(
        name: 'memory_save',
        description: 'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.',
        parameters: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'A unique key to identify this memory (e.g., "user_name", "favorite_color")',
            },
            'value': {
              'type': 'string',
              'description': 'The information to remember',
            },
          },
          'required': ['key', 'value'],
        },
      ),

      // Tool 3: Memory - Recall from long-term storage
      ToolDefinition(
        name: 'memory_recall',
        description: 'Recall information from long-term memory. Use this when you need to remember something the user previously asked you to save.',
        parameters: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The key of the memory to recall. Use "all" to get all stored memories.',
            },
          },
          'required': ['key'],
        },
      ),

      // Tool 4: Memory - Delete from storage
      ToolDefinition(
        name: 'memory_delete',
        description: 'Delete information from long-term memory. Use this when the user asks you to forget something.',
        parameters: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The key of the memory to delete. Use "all" to delete all memories.',
            },
          },
          'required': ['key'],
        },
      ),

      // Tool 5: Simple calculator
      ToolDefinition(
        name: 'calculator',
        description: 'Perform basic arithmetic calculations. Use this for mathematical operations.',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'Mathematical expression to evaluate (e.g., "2 + 3 * 4", "100 / 5")',
            },
          },
          'required': ['expression'],
        },
      ),
    ];
  }
}
