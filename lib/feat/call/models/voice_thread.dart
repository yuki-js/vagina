import 'package:vagina/feat/call/models/rt_conversation_item.dart';

/// Immutable snapshot of a realtime conversation thread for a single call.
class VoiceThread {
  final String id;
  final String? sessionId;
  final String? conversationId;
  final String? provider;
  final int sequence;
  final List<RtConversationItem> items;

  VoiceThread({
    required this.id,
    this.sessionId,
    this.conversationId,
    this.provider,
    this.sequence = 0,
    List<RtConversationItem> items = const [],
  }) : items = List<RtConversationItem>.unmodifiable(items);

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  int get length => items.length;

  RtConversationItem? get lastItem => items.isEmpty ? null : items.last;

  int indexOfItemId(String id) {
    for (var index = 0; index < items.length; index++) {
      if (items[index].id == id) {
        return index;
      }
    }

    return -1;
  }

  VoiceThread appendItem(RtConversationItem item) {
    return VoiceThread(
      id: id,
      sessionId: sessionId,
      conversationId: conversationId,
      provider: provider,
      sequence: sequence + 1,
      items: [...items, item],
    );
  }

  VoiceThread upsertItem(RtConversationItem item) {
    final itemId = item.id;
    if (itemId == null) {
      return appendItem(item);
    }

    final existingIndex = indexOfItemId(itemId);
    if (existingIndex == -1) {
      return appendItem(item);
    }

    final nextItems = List<RtConversationItem>.of(items);
    nextItems[existingIndex] = item;

    return VoiceThread(
      id: id,
      sessionId: sessionId,
      conversationId: conversationId,
      provider: provider,
      sequence: sequence + 1,
      items: nextItems,
    );
  }
}