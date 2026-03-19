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

  void replaceWith(String value) {
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

  RealtimeThreadTextPart ensureTextPart({int? contentIndex}) {
    final index = _normalizeContentIndex(contentIndex);
    if (index != null && index < content.length) {
      final part = content[index];
      if (part is RealtimeThreadTextPart) {
        return part;
      }
    }

    final part = RealtimeThreadTextPart();
    if (index == null || index >= content.length) {
      content.add(part);
    } else {
      content.insert(index, part);
    }
    return part;
  }

  RealtimeThreadAudioPart ensureAudioPart({int? contentIndex}) {
    final index = _normalizeContentIndex(contentIndex);
    if (index != null && index < content.length) {
      final part = content[index];
      if (part is RealtimeThreadAudioPart) {
        return part;
      }
    }

    final part = RealtimeThreadAudioPart();
    if (index == null || index >= content.length) {
      content.add(part);
    } else {
      content.insert(index, part);
    }
    return part;
  }

  void appendTextDelta(String delta, {int? contentIndex}) {
    ensureTextPart(contentIndex: contentIndex).appendDelta(delta);
  }

  void setTextDone(String text, {int? contentIndex}) {
    final part = ensureTextPart(contentIndex: contentIndex);
    part.replaceWith(text);
    part.isDone = true;
  }

  void appendAudioDelta(String base64Delta, {int? contentIndex}) {
    ensureAudioPart(contentIndex: contentIndex).appendAudioDelta(base64Delta);
  }

  void markAudioDone({int? contentIndex}) {
    ensureAudioPart(contentIndex: contentIndex).isDone = true;
  }

  void appendAudioTranscriptDelta(String delta, {int? contentIndex}) {
    ensureAudioPart(contentIndex: contentIndex).appendTranscriptDelta(delta);
  }

  void setAudioTranscriptDone(String transcript, {int? contentIndex}) {
    final part = ensureAudioPart(contentIndex: contentIndex);
    part.replaceTranscript(transcript);
    part.isDone = true;
  }

  void appendFunctionArgumentsDelta(String delta) {
    arguments = (arguments ?? '') + delta;
  }

  void setFunctionArgumentsDone({
    String? callId,
    String? name,
    String? arguments,
  }) {
    this.callId = callId ?? this.callId;
    this.name = name ?? this.name;
    this.arguments = arguments ?? this.arguments;
  }

  void addImagePart(String imageUrl, {String detail = 'auto'}) {
    content.add(
      RealtimeThreadImagePart(
        imageUrl: imageUrl,
        detail: detail,
      ),
    );
  }

  void markContentPartDone(int contentIndex) {
    if (contentIndex < 0 || contentIndex >= content.length) {
      return;
    }
    content[contentIndex].isDone = true;
  }

  void markDone() {
    status = RealtimeThreadItemStatus.completed;
    for (final part in content) {
      part.isDone = true;
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
