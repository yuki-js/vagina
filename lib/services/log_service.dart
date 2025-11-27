import 'dart:async';

/// Log entry with timestamp and message
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    return '[$time] [$level] [$tag] $message';
  }
}

/// Singleton logging service for trace logs
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  
  // Maximum number of logs to keep in memory
  static const int _maxLogs = 1000;

  /// Stream of new log entries
  Stream<LogEntry> get logStream => _logController.stream;

  /// Get all logs
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Log an info message
  void info(String tag, String message) {
    _addLog('INFO', tag, message);
  }

  /// Log a debug message
  void debug(String tag, String message) {
    _addLog('DEBUG', tag, message);
  }

  /// Log a warning message
  void warn(String tag, String message) {
    _addLog('WARN', tag, message);
  }

  /// Log an error message
  void error(String tag, String message) {
    _addLog('ERROR', tag, message);
  }

  /// Log WebSocket events (without base64 audio data)
  void websocket(String direction, String eventType, [Map<String, dynamic>? data]) {
    String message = '$direction $eventType';
    if (data != null) {
      // Filter out audio base64 data to prevent log explosion
      final filteredData = Map<String, dynamic>.from(data);
      if (filteredData.containsKey('audio')) {
        final audioLength = (filteredData['audio'] as String?)?.length ?? 0;
        filteredData['audio'] = '[BASE64 audio data, length: $audioLength]';
      }
      if (filteredData.containsKey('delta') && eventType.contains('audio')) {
        final deltaLength = (filteredData['delta'] as String?)?.length ?? 0;
        filteredData['delta'] = '[BASE64 audio delta, length: $deltaLength]';
      }
      message += ' $filteredData';
    }
    _addLog('WS', 'WebSocket', message);
  }

  void _addLog(String level, String tag, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    
    _logs.add(entry);
    
    // Trim logs if exceeded maximum
    while (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    _logController.add(entry);
    
    // Also print to console for debugging
    // ignore: avoid_print
    print(entry.toString());
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Export logs as string
  String export() {
    return _logs.map((e) => e.toString()).join('\n');
  }

  /// Dispose the service
  void dispose() {
    _logController.close();
  }
}

/// Global log service instance
final logService = LogService();
