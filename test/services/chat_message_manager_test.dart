import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/services/chat/chat_message_manager.dart';

void main() {
  group('ChatMessageManager', () {
    late ChatMessageManager manager;

    setUp(() {
      manager = ChatMessageManager();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test(
        'adds tool call to new assistant message when no current message exists',
        () {
      manager.addToolCall('calculator', '{"a": 1, "b": 2}', '3');

      final messages = manager.chatMessages;
      expect(messages.length, 1);
      expect(messages[0].role, 'assistant');
      expect(messages[0].content, '');
      expect(messages[0].toolCalls.length, 1);
      expect(messages[0].toolCalls[0].name, 'calculator');
    });

    test('adds tool call to existing assistant message', () {
      // Start assistant message
      manager.appendAssistantTranscript('こんにちは');

      // Add tool call
      manager.addToolCall('calculator', '{"a": 1}', '1');

      final messages = manager.chatMessages;
      expect(messages.length, 1);
      expect(messages[0].role, 'assistant');
      expect(messages[0].content, 'こんにちは');
      expect(messages[0].toolCalls.length, 1);
      expect(messages[0].toolCalls[0].name, 'calculator');
    });

    test('merges multiple tool calls into single assistant message', () {
      // Add first tool call (creates assistant message)
      manager.addToolCall('calculator', '{"a": 1}', '1');

      // Add second tool call
      manager.addToolCall('weather', '{"city": "Tokyo"}', 'Sunny');

      // Add transcript
      manager.appendAssistantTranscript('計算結果は1で、東京は晴れです。');

      final messages = manager.chatMessages;
      expect(messages.length, 1);
      expect(messages[0].role, 'assistant');
      expect(messages[0].toolCalls.length, 2);
      expect(messages[0].toolCalls[0].name, 'calculator');
      expect(messages[0].toolCalls[1].name, 'weather');
    });

    test('tool calls are preserved in order', () {
      manager.addToolCall('first_tool', '{}', '1');
      manager.addToolCall('second_tool', '{}', '2');
      manager.addToolCall('third_tool', '{}', '3');

      final toolCalls = manager.chatMessages[0].toolCalls;
      expect(toolCalls[0].name, 'first_tool');
      expect(toolCalls[1].name, 'second_tool');
      expect(toolCalls[2].name, 'third_tool');
    });

    test('completes assistant message and resets tool calls', () {
      manager.addToolCall('calculator', '{}', '1');
      manager.appendAssistantTranscript('結果は1です');
      manager.completeCurrentAssistantMessage();

      // First message should be complete
      expect(manager.chatMessages[0].isComplete, true);

      // Start new turn - should be a new message
      manager.appendAssistantTranscript('次の回答');

      expect(manager.chatMessages.length, 2);
      expect(manager.chatMessages[1].toolCalls.isEmpty, true);
    });

    test('clears tool calls when clearing chat', () {
      manager.addToolCall('calculator', '{}', '1');
      manager.clearChat();

      expect(manager.chatMessages.isEmpty, true);
    });

    test('user message does not have tool calls', () {
      manager.addChatMessage('user', 'Hello');

      expect(manager.chatMessages[0].toolCalls.isEmpty, true);
    });

    test('text and tool calls are interleaved in correct order', () {
      // Simulate: "了解しました" -> [calculator] -> "結果は3です"
      manager.appendAssistantTranscript('了解しました');
      manager.addToolCall('calculator', '{"a": 1, "b": 2}', '3');
      manager.appendAssistantTranscript('結果は3です');

      final message = manager.chatMessages[0];
      expect(message.contentParts.length, 3);

      // First part: text
      expect(message.contentParts[0], isA<TextPart>());
      expect((message.contentParts[0] as TextPart).text, '了解しました');

      // Second part: tool call
      expect(message.contentParts[1], isA<ToolCallPart>());
      expect((message.contentParts[1] as ToolCallPart).toolCall.name,
          'calculator');

      // Third part: text
      expect(message.contentParts[2], isA<TextPart>());
      expect((message.contentParts[2] as TextPart).text, '結果は3です');
    });

    test('multiple tool calls between text parts', () {
      // Simulate: "ツールを使います" -> [tool1] -> [tool2] -> "両方完了"
      manager.appendAssistantTranscript('ツールを使います');
      manager.addToolCall('tool1', '{}', 'result1');
      manager.addToolCall('tool2', '{}', 'result2');
      manager.appendAssistantTranscript('両方完了');

      final message = manager.chatMessages[0];
      expect(message.contentParts.length, 4);

      expect(message.contentParts[0], isA<TextPart>());
      expect(message.contentParts[1], isA<ToolCallPart>());
      expect(message.contentParts[2], isA<ToolCallPart>());
      expect(message.contentParts[3], isA<TextPart>());

      // Verify combined content
      expect(message.content, 'ツールを使います両方完了');
      expect(message.toolCalls.length, 2);
    });

    test('tool call at the start followed by text', () {
      // Simulate: [calculator] -> "答えは42です"
      manager.addToolCall('calculator', '{}', '42');
      manager.appendAssistantTranscript('答えは42です');

      final message = manager.chatMessages[0];
      expect(message.contentParts.length, 2);

      expect(message.contentParts[0], isA<ToolCallPart>());
      expect(message.contentParts[1], isA<TextPart>());
    });
  });
}
