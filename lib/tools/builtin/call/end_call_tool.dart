import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class EndCallTool extends Tool {
  static const String toolKeyName = 'end_call';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: '通話終了',
        displayDescription: '現在の通話を終了します',
        categoryKey: 'call',
        iconKey: 'call_end',
        sourceKey: 'builtin',
        description:
            'End the current voice call. Use when conversation naturally concludes or user requests to end.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'end_context': {
              'type': 'string',
              'description':
                  'Optional context about why the call is ending (e.g., "natural conclusion", "user request", "ultra_long processing")',
            },
          },
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final endContext = args['end_context'] as String?;

    try {
      // Call the call API to end the call
      final success = await context.callApi.endCall(endContext: endContext);

      if (success) {
        return jsonEncode({
          'success': true,
          'ended': true,
        });
      } else {
        return jsonEncode({
          'success': false,
          'error': 'Failed to end call',
        });
      }
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Error ending call: $e',
      });
    }
  }
}
