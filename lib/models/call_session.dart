/// Represents a simple notepad tab for session history
class SessionNotepadTab {
  final String title;
  final String content;

  const SessionNotepadTab({
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
    };
  }

  factory SessionNotepadTab.fromJson(Map<String, dynamic> json) {
    return SessionNotepadTab(
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }
}

/// Represents a single call session with metadata and chat history
class CallSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int duration; // in seconds
  final List<String> chatMessages; // JSON-encoded messages
  final List<SessionNotepadTab>? notepadTabs; // Structured notepad tabs
  final String speedDialId; // Reference to speed dial used (non-nullable)

  const CallSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.duration = 0,
    this.chatMessages = const [],
    this.notepadTabs,
    required this.speedDialId,
  });

  CallSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    List<String>? chatMessages,
    List<SessionNotepadTab>? notepadTabs,
    String? speedDialId,
  }) {
    return CallSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      chatMessages: chatMessages ?? this.chatMessages,
      notepadTabs: notepadTabs ?? this.notepadTabs,
      speedDialId: speedDialId ?? this.speedDialId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'duration': duration,
      'chatMessages': chatMessages,
      if (notepadTabs != null) 'notepadTabs': notepadTabs!.map((t) => t.toJson()).toList(),
      'speedDialId': speedDialId,
    };
  }

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String)
          : null,
      duration: json['duration'] as int? ?? 0,
      chatMessages: (json['chatMessages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      notepadTabs: (json['notepadTabs'] as List<dynamic>?)
              ?.map((e) => SessionNotepadTab.fromJson(e as Map<String, dynamic>))
              .toList(),
      speedDialId: json['speedDialId'] as String,
    );
  }
}
