import 'package:flutter/material.dart';
import '../base_tool.dart';
import '../tool_metadata.dart';
import '../../../utils/duration_formatter.dart';

/// 現在時刻取得ツール
class GetCurrentTimeTool extends BaseTool {
  @override
  String get name => 'get_current_time';
  
  @override
  String get description => 
      'Get the current date and time. Use this when the user asks about the current time or date.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'timezone': {
        'type': 'string',
        'description': 'Timezone name (e.g., "Asia/Tokyo", "UTC"). Defaults to local time if not specified.',
      },
    },
    'required': [],
  };
  
  @override
  ToolMetadata get metadata => const ToolMetadata(
    name: 'get_current_time',
    displayName: '現在時刻',
    displayDescription: '現在の日時を取得します',
    description: 'Get the current date and time. Use this when the user asks about the current time or date.',
    icon: Icons.access_time,
    category: ToolCategory.system,
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final timezone = arguments['timezone'] as String?;
    
    return {
      'current_time': now.toIso8601String(),
      'formatted': DurationFormatter.formatJapaneseDateTime(now),
      'timezone': timezone ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    };
  }
}
