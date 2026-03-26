import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  test('Logging package integration test', () {
    // Setup logging
    Logger.root.level = Level.ALL;
    final logs = <LogRecord>[];
    
    Logger.root.onRecord.listen((record) {
      logs.add(record);
    });

    // Create loggers
    final testLogger = Logger('TestLogger');
    final webSocketLogger = Logger('WebSocket');

    // Test different log levels
    testLogger.fine('This is a FINE level message');
    testLogger.info('This is an INFO level message');
    testLogger.warning('This is a WARNING level message');
    testLogger.severe('This is a SEVERE (ERROR) level message');

    // Test with error and stack trace
    try {
      throw Exception('Test exception');
    } catch (e, stack) {
      testLogger.severe('Error occurred', e, stack);
    }

    // Test WebSocket style logging
    webSocketLogger.info('SEND session.update');
    webSocketLogger.info('RECV response.audio.delta');

    // Verify logs were captured
    expect(logs.length, greaterThanOrEqualTo(7));
    expect(logs.any((log) => log.level == Level.FINE), isTrue);
    expect(logs.any((log) => log.level == Level.INFO), isTrue);
    expect(logs.any((log) => log.level == Level.WARNING), isTrue);
    expect(logs.any((log) => log.level == Level.SEVERE), isTrue);
    expect(logs.any((log) => log.loggerName == 'TestLogger'), isTrue);
    expect(logs.any((log) => log.loggerName == 'WebSocket'), isTrue);

    // Verify error was logged
    final errorLog = logs.firstWhere((log) => log.error != null);
    expect(errorLog.error, isA<Exception>());
    expect(errorLog.stackTrace, isNotNull);

    print('\n✅ All logging tests passed!');
    print('📊 Total logs captured: ${logs.length}');
  });
}
