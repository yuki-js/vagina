library;

/// Semi-mutable thread model for realtime chat.
///
/// - The thread/items are intentionally mutable to support efficient delta
///   accumulation.
/// - Once `isDone` becomes true, that part/item is expected to become stable.

enum RealtimeThreadItemType {
  message,
  functionCall,
  functionCallOutput,
}

enum RealtimeThreadItemRole {
  system,
  user,
  assistant,
}

enum RealtimeThreadItemStatus {
  inProgress('in_progress'),
  completed('completed'),
  incomplete('incomplete');

  final String wireValue;

  const RealtimeThreadItemStatus(this.wireValue);

  static RealtimeThreadItemStatus fromWireValue(String? value) {
    return switch (value) {
      'completed' => RealtimeThreadItemStatus.completed,
      'incomplete' => RealtimeThreadItemStatus.incomplete,
      _ => RealtimeThreadItemStatus.inProgress,
    };
  }
}

abstract class RealtimeThreadContentPart {
  final String type;
  bool isDone;

  RealtimeThreadContentPart({
    required this.type,
    this.isDone = false,
  });

  void markDone() {
    isDone = true;
  }
}

final class RealtimeThreadTextPart extends RealtimeThreadContentPart {
  String text;

  RealtimeThreadTextPart({
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

final class RealtimeThreadAudioPart extends RealtimeThreadContentPart {
  final List<String> audioChunks;
  String? transcript;

  RealtimeThreadAudioPart({
    List<String>? audioChunks,
    this.transcript,
    super.isDone,
  })  : audioChunks = audioChunks ?? <String>[],
        super(type: 'audio');

  void appendAudioDelta(String base64Delta) {
    audioChunks.add(base64Delta);
  }

  void replaceAudio(String base64Audio) {
    audioChunks
      ..clear()
      ..add(base64Audio);
  }

  void appendTranscriptDelta(String delta) {
    transcript = (transcript ?? '') + delta;
  }

  void replaceTranscript(String value) {
    transcript = value;
  }

  String get fullAudioBase64 => audioChunks.join();
}

final class RealtimeThreadImagePart extends RealtimeThreadContentPart {
  final String imageUrl;
  final String detail;

  RealtimeThreadImagePart({
    required this.imageUrl,
    this.detail = 'auto',
  }) : super(type: 'image', isDone: true);
}

final class RealtimeThread {
  final String id;
  String? conversationId;
  final List<RealtimeThreadItem> items;

  RealtimeThread({
    required this.id,
    this.conversationId,
    List<RealtimeThreadItem>? items,
  }) : items = items ?? <RealtimeThreadItem>[];

  RealtimeThreadItem? findItem(String itemId) {
    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  void addItem(RealtimeThreadItem item) {
    items.add(item);
  }

  bool removeItem(String itemId) {
    final beforeLength = items.length;
    items.removeWhere((item) => item.id == itemId);
    return items.length != beforeLength;
  }
}

final class RealtimeThreadItem {
  final String id;
  final RealtimeThreadItemType type;
  RealtimeThreadItemRole? role;
  RealtimeThreadItemStatus status;
  final List<RealtimeThreadContentPart> content;
  String? callId;
  String? name;
  String? arguments;
  String? output;

  RealtimeThreadItem({
    required this.id,
    required this.type,
    this.role,
    this.status = RealtimeThreadItemStatus.inProgress,
    List<RealtimeThreadContentPart>? content,
    this.callId,
    this.name,
    this.arguments,
    this.output,
  }) : content = content ?? <RealtimeThreadContentPart>[];

  bool get isDone => status == RealtimeThreadItemStatus.completed;

  RealtimeThreadContentPart? findContentPart(int contentIndex) {
    final index = _normalizeContentIndex(contentIndex);
    if (index == null || index >= content.length) {
      return null;
    }
    return content[index];
  }

  RealtimeThreadContentPart getContentPart(int contentIndex) {
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
    RealtimeThreadContentPart part, {
    int? contentIndex,
  }) {
    final index = _normalizeContentIndex(contentIndex);
    if (index == null || index >= content.length) {
      content.add(part);
      return;
    }
    content[index] = part;
  }

  void addContentPart(RealtimeThreadContentPart part) {
    content.add(part);
  }

  void markDone() {
    status = RealtimeThreadItemStatus.completed;
    for (final part in content) {
      part.markDone();
    }
  }

  void markIncomplete() {
    status = RealtimeThreadItemStatus.incomplete;
  }

  int? _normalizeContentIndex(int? contentIndex) {
    if (contentIndex == null || contentIndex < 0) {
      return null;
    }
    return contentIndex;
  }
}
