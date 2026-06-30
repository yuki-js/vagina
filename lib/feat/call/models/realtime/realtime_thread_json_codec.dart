import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';

final class RealtimeThreadJsonDecodeException implements Exception {
  final String message;

  const RealtimeThreadJsonDecodeException(this.message);

  @override
  String toString() => message;
}

final class RealtimeThreadJsonCodec {
  const RealtimeThreadJsonCodec._();

  static RealtimeThread fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const RealtimeThreadJsonDecodeException(
        'Saved thread is missing a valid id.',
      );
    }

    final conversationId = json['conversationId'];
    if (conversationId != null && conversationId is! String) {
      throw const RealtimeThreadJsonDecodeException(
        'Saved thread conversationId must be a string or null.',
      );
    }

    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const RealtimeThreadJsonDecodeException(
        'Saved thread items must be a list.',
      );
    }

    final items = <RealtimeThreadItem>[];
    for (var index = 0; index < rawItems.length; index++) {
      final rawItem = rawItems[index];
      if (rawItem is! Map) {
        throw RealtimeThreadJsonDecodeException(
          'Saved thread item at index $index must be an object.',
        );
      }
      items.add(itemFromJson(_stringKeyedMap(rawItem)));
    }

    return RealtimeThread(id: id, conversationId: conversationId, items: items);
  }

  static RealtimeThreadItem itemFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const RealtimeThreadJsonDecodeException(
        'Saved thread item is missing a valid id.',
      );
    }

    final item = RealtimeThreadItem(
      id: id,
      type: itemTypeFromWireValue(json['type'] as String?),
      role: roleFromWireValue(json['role'] as String?),
      status: RealtimeThreadItemStatus.fromWireValue(json['status'] as String?),
      displayState: RealtimeThreadItemDisplayState.fromWireValue(
        json['displayState'] as String?,
      ),
      callId: json['callId'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
      output: json['output'] as String?,
      toolOutputDisposition: toolOutputDispositionFromWireValue(
        json['toolOutputDisposition'] as String?,
      ),
      toolErrorMessage: json['toolErrorMessage'] as String?,
    );

    final rawContent = json['content'];
    if (rawContent == null) {
      return item;
    }
    if (rawContent is! List) {
      throw RealtimeThreadJsonDecodeException(
        'Saved thread item "$id" content must be a list when present.',
      );
    }

    for (var index = 0; index < rawContent.length; index++) {
      final rawPart = rawContent[index];
      if (rawPart is! Map) {
        throw RealtimeThreadJsonDecodeException(
          'Saved thread item "$id" content[$index] must be an object.',
        );
      }
      final part = partFromJson(_stringKeyedMap(rawPart));
      if (part != null) {
        item.addContentPart(part);
      }
    }

    return item;
  }

  static RealtimeThreadContentPart? partFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final isDone = json['isDone'] as bool? ?? false;

    return switch (type) {
      'text' => RealtimeThreadTextPart(
        text: json['text'] as String? ?? '',
        isDone: isDone,
      ),
      'audio' => RealtimeThreadAudioPart(
        transcript: json['transcript'] as String?,
        isDone: isDone,
      ),
      'image' => RealtimeThreadImagePart(
        imageUrl: json['imageUrl'] as String? ?? '',
        detail: json['detail'] as String? ?? 'auto',
      ),
      _ => null,
    };
  }

  static RealtimeThreadItemType itemTypeFromWireValue(String? value) {
    return switch (value) {
      'functionCall' => RealtimeThreadItemType.functionCall,
      'functionCallOutput' => RealtimeThreadItemType.functionCallOutput,
      _ => RealtimeThreadItemType.message,
    };
  }

  static RealtimeThreadItemRole? roleFromWireValue(String? value) {
    return switch (value) {
      'system' => RealtimeThreadItemRole.system,
      'user' => RealtimeThreadItemRole.user,
      'assistant' => RealtimeThreadItemRole.assistant,
      _ => null,
    };
  }

  static RealtimeToolOutputDisposition? toolOutputDispositionFromWireValue(
    String? value,
  ) {
    return switch (value) {
      'success' => RealtimeToolOutputDisposition.success,
      'error' => RealtimeToolOutputDisposition.error,
      _ => null,
    };
  }

  static Map<String, dynamic> _stringKeyedMap(Map raw) {
    return raw.map((key, value) => MapEntry(key as String, value));
  }
}
