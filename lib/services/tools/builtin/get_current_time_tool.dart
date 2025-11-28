import '../base_tool.dart';

/// Tool for getting the current date and time
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
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final timezone = arguments['timezone'] as String?;
    
    return {
      'current_time': now.toIso8601String(),
      'formatted': '${now.year}年${now.month}月${now.day}日 ${now.hour}時${now.minute}分${now.second}秒',
      'timezone': timezone ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    };
  }
}
