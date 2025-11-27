import 'dart:async';

/// Log entry with timestamp and message
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  int repeatCount;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.repeatCount = 1,
  });

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    if (repeatCount > 1) {
      return '[$time] [$level] [$tag] $message (x$repeatCount)';
    }
    return '[$time] [$level] [$tag] $message';
  }
}

/// Singleton logging service for trace logs with similar log reduction
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  
  // Maximum number of logs to keep in memory (similar logs don't count toward this)
  static const int _maxLogs = 1000;
  
  // Time window for similar log detection (3 seconds)
  static const Duration _similarLogWindow = Duration(seconds: 3);
  
  // Track last logs by signature for deduplication
  // Key: log signature (level + tag + normalized message pattern)
  // Value: (last entry, last timestamp)
  final Map<String, (LogEntry, DateTime)> _recentLogs = {};

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
  
  /// Generate a signature for similar log detection
  /// This normalizes the message to detect "similar" logs (not just identical)
  String _generateSignature(String level, String tag, String message) {
    // Normalize the message by:
    // 1. Removing numbers (chunk counts, byte sizes, etc.)
    // 2. Removing variable data like timestamps, IDs
    String normalized = message
        .replaceAll(RegExp(r'\d+'), '#')  // Replace numbers with #
        .replaceAll(RegExp(r'#\.#'), '#')  // Simplify decimal numbers
        .replaceAll(RegExp(r'#+'), '#')    // Collapse multiple # into one
        .replaceAll(RegExp(r'\s+'), ' ')   // Normalize whitespace
        .trim();
    
    return '$level|$tag|$normalized';
  }
  
  /// Check if a similar log was recently added
  /// Returns the recent entry if found, null otherwise
  LogEntry? _findSimilarRecentLog(String signature, DateTime now) {
    final recent = _recentLogs[signature];
    if (recent == null) return null;
    
    final (entry, lastTime) = recent;
    
    // Check if within time window OR if it's the immediately preceding log
    // (even if more than 3 seconds passed, as long as no different log in between)
    final withinTimeWindow = now.difference(lastTime) <= _similarLogWindow;
    final isLastLog = _logs.isNotEmpty && _logs.last == entry;
    
    if (withinTimeWindow || isLastLog) {
      return entry;
    }
    
    return null;
  }

  void _addLog(String level, String tag, String message) {
    final now = DateTime.now();
    final signature = _generateSignature(level, tag, message);
    
    // Check for similar recent log
    final similarEntry = _findSimilarRecentLog(signature, now);
    
    if (similarEntry != null) {
      // Increment repeat count of existing entry
      similarEntry.repeatCount++;
      _recentLogs[signature] = (similarEntry, now);
      
      // Notify listeners of the update
      _logController.add(similarEntry);
      
      // Also print to console for debugging
      // ignore: avoid_print
      print(similarEntry.toString());
      return;
    }
    
    // Create new entry
    final entry = LogEntry(
      timestamp: now,
      level: level,
      tag: tag,
      message: message,
    );
    
    _logs.add(entry);
    _recentLogs[signature] = (entry, now);
    
    // Clean up old entries from _recentLogs periodically
    _cleanupRecentLogs(now);
    
    // Trim logs if exceeded maximum (only count unique entries)
    while (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    _logController.add(entry);
    
    // Also print to console for debugging
    // ignore: avoid_print
    print(entry.toString());
  }
  
  /// Clean up old entries from _recentLogs map
  void _cleanupRecentLogs(DateTime now) {
    final keysToRemove = <String>[];
    
    for (final entry in _recentLogs.entries) {
      final (logEntry, lastTime) = entry.value;
      // Remove if older than time window AND not in the log list anymore
      if (now.difference(lastTime) > _similarLogWindow && !_logs.contains(logEntry)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _recentLogs.remove(key);
    }
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
    _recentLogs.clear();
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
