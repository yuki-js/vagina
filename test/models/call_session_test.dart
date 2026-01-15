import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/speed_dial.dart';

void main() {
  group('CallSession', () {
    test('should create a call session with required fields', () {
      final session = CallSession(
        id: 'test-session-1',
        startTime: DateTime.parse('2026-01-15T12:00:00Z'),
        speedDialId: SpeedDial.defaultId,
      );

      expect(session.id, equals('test-session-1'));
      expect(session.startTime, equals(DateTime.parse('2026-01-15T12:00:00Z')));
      expect(session.speedDialId, equals(SpeedDial.defaultId));
      expect(session.endTime, isNull);
      expect(session.duration, equals(0));
      expect(session.chatMessages, isEmpty);
      expect(session.notepadTabs, isNull);
    });

    test('should serialize and deserialize correctly', () {
      final session = CallSession(
        id: 'test-session-1',
        startTime: DateTime.parse('2026-01-15T12:00:00Z'),
        endTime: DateTime.parse('2026-01-15T12:30:00Z'),
        duration: 1800,
        chatMessages: ['{"role": "user", "content": "Hello"}'],
        speedDialId: 'custom-char-1',
      );

      final json = session.toJson();
      final deserialized = CallSession.fromJson(json);

      expect(deserialized.id, equals(session.id));
      expect(deserialized.startTime, equals(session.startTime));
      expect(deserialized.endTime, equals(session.endTime));
      expect(deserialized.duration, equals(session.duration));
      expect(deserialized.chatMessages, equals(session.chatMessages));
      expect(deserialized.speedDialId, equals(session.speedDialId));
    });

    test('should use default speedDialId when missing in JSON', () {
      // Simulating old data format without speedDialId
      final json = {
        'id': 'test-session-1',
        'startTime': '2026-01-15T12:00:00Z',
        'duration': 300,
      };

      final session = CallSession.fromJson(json);
      expect(session.speedDialId, equals(SpeedDial.defaultId));
    });

    test('should handle notepad tabs correctly', () {
      final session = CallSession(
        id: 'test-session-1',
        startTime: DateTime.now(),
        speedDialId: SpeedDial.defaultId,
        notepadTabs: [
          SessionNotepadTab(title: 'Note 1', content: 'Content 1'),
          SessionNotepadTab(title: 'Note 2', content: 'Content 2'),
        ],
      );

      final json = session.toJson();
      final deserialized = CallSession.fromJson(json);

      expect(deserialized.notepadTabs, isNotNull);
      expect(deserialized.notepadTabs!.length, equals(2));
      expect(deserialized.notepadTabs![0].title, equals('Note 1'));
      expect(deserialized.notepadTabs![1].content, equals('Content 2'));
    });

    test('should copy with modifications', () {
      final original = CallSession(
        id: 'test-session-1',
        startTime: DateTime.parse('2026-01-15T12:00:00Z'),
        speedDialId: SpeedDial.defaultId,
      );

      final modified = original.copyWith(
        endTime: DateTime.parse('2026-01-15T12:30:00Z'),
        duration: 1800,
      );

      expect(modified.id, equals(original.id));
      expect(modified.startTime, equals(original.startTime));
      expect(modified.endTime, equals(DateTime.parse('2026-01-15T12:30:00Z')));
      expect(modified.duration, equals(1800));
      expect(modified.speedDialId, equals(original.speedDialId));
    });
  });

  group('SessionNotepadTab', () {
    test('should serialize and deserialize correctly', () {
      final tab = SessionNotepadTab(
        title: 'My Note',
        content: 'This is the content',
      );

      final json = tab.toJson();
      final deserialized = SessionNotepadTab.fromJson(json);

      expect(deserialized.title, equals(tab.title));
      expect(deserialized.content, equals(tab.content));
    });
  });
}
