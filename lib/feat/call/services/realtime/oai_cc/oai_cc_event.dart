import 'dart:convert';

/// Base class for events emitted by the OpenAI Chat Completions stream.
abstract class OaiCcEvent {
  const OaiCcEvent();
}

/// A content delta event containing partial text.
final class OaiCcContentDeltaEvent extends OaiCcEvent {
  final String content;

  const OaiCcContentDeltaEvent({required this.content});
}

/// An event signaling the stream is finished.
final class OaiCcFinishedEvent extends OaiCcEvent {
  final String? finishReason;

  const OaiCcFinishedEvent({this.finishReason});
}

/// An error event occurred during stream reading.
final class OaiCcErrorEvent extends OaiCcEvent {
  final String message;

  const OaiCcErrorEvent({required this.message});
}

/// Parser utility to translate SSE lines to [OaiCcEvent]s.
final class OaiCcEventParser {
  const OaiCcEventParser();

  /// Parses a single raw SSE line (e.g. `data: {"choices": [...]}`).
  /// Returns `null` if the line does not contain standard event data or is empty/comment.
  OaiCcEvent? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('data:')) return null;

    final dataValue = trimmed.substring(5).trim();
    if (dataValue == '[DONE]') {
      return const OaiCcFinishedEvent();
    }

    try {
      final json = jsonDecode(dataValue) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final choice = choices.first as Map<String, dynamic>;
        final delta = choice['delta'] as Map<String, dynamic>?;
        final finishReason = choice['finish_reason'] as String?;

        if (finishReason != null) {
          return OaiCcFinishedEvent(finishReason: finishReason);
        }

        if (delta != null && delta.containsKey('content')) {
          final content = delta['content'] as String? ?? '';
          if (content.isNotEmpty) {
            return OaiCcContentDeltaEvent(content: content);
          }
        }
      }
    } catch (e) {
      return OaiCcErrorEvent(message: 'Failed to parse JSON chunk: $e');
    }

    return null;
  }
}
