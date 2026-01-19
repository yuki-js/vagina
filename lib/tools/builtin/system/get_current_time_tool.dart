import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/utils/duration_formatter.dart';

class GetCurrentTimeTool extends Tool {
  static const String toolKeyName = 'get_current_time';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: '現在時刻',
        displayDescription: '現在の日時を取得します',
        categoryKey: 'system',
        iconKey: 'access_time',
        sourceKey: 'builtin',
        description:
            'Get the current date and time. Use this when the user asks about the current time or date.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'timezone': {
              'type': 'string',
              'description':
                  'Timezone name (e.g., "Asia/Tokyo", "UTC"). Defaults to local time if not specified.',
            },
          },
          'required': [],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final now = DateTime.now();
    final timezone = args['timezone'] as String?;

    return jsonEncode({
      'current_time': now.toIso8601String(),
      'formatted': DurationFormatter.formatJapaneseDateTime(now),
      'timezone': timezone ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    });
  }
}
