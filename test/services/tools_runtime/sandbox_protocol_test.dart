import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';

void main() {
  group('sandbox protocol', () {
    test('setTextAgentVisibleToolsMessage builds valid envelope', () {
      final message = setTextAgentVisibleToolsMessage(
        ['tool_a', 'tool_b'],
        id: 'req-1',
      );

      expect(message['type'], MessageType.setTextAgentVisibleTools);
      expect(message['id'], 'req-1');
      expect(message['payload'], {
        'toolKeys': ['tool_a', 'tool_b'],
      });

      final (valid, error) = validateMessageEnvelope(message);
      expect(valid, isTrue, reason: error);
    });

    test('setTextAgentVisibleToolsMessage keeps empty list sendable', () {
      final message = setTextAgentVisibleToolsMessage(const []);
      final payload = message['payload'] as Map<String, dynamic>;

      expect(payload['toolKeys'], isA<List<dynamic>>());

      final (valid, error) = validateMessageEnvelope(message);
      expect(valid, isTrue, reason: error);
    });
  });
}
