/// Provider-agnostic thread model for a single CallService text-agent session.
///
/// This is intentionally a domain model, not a direct Chat Completions payload.
/// It keeps the conversation as typed items so transport-specific serialization
/// can be implemented separately.
///
/// Design notes:
/// - Semi-mutable for efficient in-place assembly and future streaming support.
/// - Text-first: only text content parts are modeled for now.
/// - Tool calls are modeled as part of assistant messages (matching all major
///   provider APIs), while tool results remain independent items.
/// - Suitable for APIs that are request/response based, even when they do not
///   expose realtime item events like the voice stack does.

enum TextAgentThreadItemType {
  message,
  toolResult,
}

/// Provider-neutral tool call representation.
///
/// Represents a single tool invocation request from the assistant.
/// Multiple tool calls can be grouped in a single assistant message.
class TextAgentToolCall {
  final String id;
  final String name;
  final String arguments; // JSON string

  TextAgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

enum TextAgentThreadItemRole {
  system,
  user,
  assistant,
}

enum TextAgentThreadItemStatus {
  inProgress,
  completed,
  incomplete,
}

enum TextAgentToolResultDisposition {
  success,
  error,
}

abstract class TextAgentThreadContentPart {
  final String type;
  bool isDone;

  TextAgentThreadContentPart({
    required this.type,
    this.isDone = false,
  });

  void markDone() {
    isDone = true;
  }
}

final class TextAgentThreadTextPart extends TextAgentThreadContentPart {
  String text;

  TextAgentThreadTextPart({
    this.text = '',
    super.isDone,
  }) : super(type: 'text');

  void appendDelta(String delta) {
    text += delta;
  }

  void replaceText(String value) {
    text = value;
  }
}

final class TextAgentThread {
  final String id;
  final List<TextAgentThreadItem> items;

  TextAgentThread({
    required this.id,
    List<TextAgentThreadItem>? items,
  }) : items = items ?? <TextAgentThreadItem>[];

  TextAgentThreadItem? findItem(String itemId) {
    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  void addItem(TextAgentThreadItem item) {
    items.add(item);
  }

  bool removeItem(String itemId) {
    final beforeLength = items.length;
    items.removeWhere((item) => item.id == itemId);
    return items.length != beforeLength;
  }

  void trimLeadingItems(int count) {
    if (count <= 0 || items.isEmpty) {
      return;
    }
    final removeCount = count.clamp(0, items.length);
    items.removeRange(0, removeCount);
  }

  bool get isEmpty => items.isEmpty;
  int get length => items.length;
}

final class TextAgentThreadItem {
  final String id;
  final TextAgentThreadItemType type;
  TextAgentThreadItemRole? role;
  TextAgentThreadItemStatus status;
  final List<TextAgentThreadContentPart> content;

  /// Tool calls (for assistant messages only).
  ///
  /// When an assistant message includes tool calls, they are stored here.
  /// Multiple tool calls can be present for parallel execution.
  List<TextAgentToolCall>? toolCalls;

  /// Tool result fields (for [TextAgentThreadItemType.toolResult] items only).
  String? toolCallId;
  String? toolName;
  String? toolOutput;
  TextAgentToolResultDisposition? toolResultDisposition;
  String? toolErrorMessage;

  TextAgentThreadItem({
    required this.id,
    required this.type,
    this.role,
    this.status = TextAgentThreadItemStatus.inProgress,
    List<TextAgentThreadContentPart>? content,
    this.toolCalls,
    this.toolCallId,
    this.toolName,
    this.toolOutput,
    this.toolResultDisposition,
    this.toolErrorMessage,
  }) : content = content ?? <TextAgentThreadContentPart>[];

  bool get isDone => status == TextAgentThreadItemStatus.completed;

  TextAgentThreadContentPart? findContentPart(int contentIndex) {
    final index = _normalizeContentIndex(contentIndex);
    if (index == null || index >= content.length) {
      return null;
    }
    return content[index];
  }

  T? findLatestContentPartOfType<T extends TextAgentThreadContentPart>() {
    for (final part in content.reversed) {
      if (part is T) {
        return part;
      }
    }
    return null;
  }

  TextAgentThreadContentPart getContentPart(int contentIndex) {
    final part = findContentPart(contentIndex);
    if (part == null) {
      throw RangeError.index(
        contentIndex,
        content,
        'contentIndex',
        'Content part index is out of range.',
      );
    }
    return part;
  }

  void putContentPart(
    TextAgentThreadContentPart part, {
    int? contentIndex,
  }) {
    final index = _normalizeContentIndex(contentIndex);
    if (index == null || index >= content.length) {
      content.add(part);
      return;
    }
    content[index] = part;
  }

  void addContentPart(TextAgentThreadContentPart part) {
    content.add(part);
  }

  TextAgentThreadTextPart ensureTextPart({int? contentIndex}) {
    final normalizedIndex = _normalizeContentIndex(contentIndex);
    if (normalizedIndex != null) {
      final indexed = findContentPart(normalizedIndex);
      if (indexed is TextAgentThreadTextPart) {
        return indexed;
      }
    }

    final existing = findLatestContentPartOfType<TextAgentThreadTextPart>();
    if (existing != null && normalizedIndex == null) {
      return existing;
    }

    final created = TextAgentThreadTextPart();
    putContentPart(created, contentIndex: normalizedIndex);
    return created;
  }

  void markDone() {
    status = TextAgentThreadItemStatus.completed;
    for (final part in content) {
      part.markDone();
    }
  }

  void markIncomplete() {
    status = TextAgentThreadItemStatus.incomplete;
  }

  int? _normalizeContentIndex(int? contentIndex) {
    if (contentIndex == null || contentIndex < 0) {
      return null;
    }
    return contentIndex;
  }
}
