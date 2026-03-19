import 'dart:convert';
import 'dart:io';

/// Loads recorded Realtime API fixtures for testing.
final class RealtimeFixtureLoader {
  final String fixturePath;
  late final RealtimeFixture _fixture;

  RealtimeFixtureLoader(this.fixturePath);

  /// Loads the fixture from disk.
  Future<void> load() async {
    final file = File(fixturePath);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    _fixture = RealtimeFixture.fromJson(json);
  }

  /// Returns the loaded fixture.
  RealtimeFixture get fixture => _fixture;

  /// Returns all received events (server -> client).
  List<Map<String, dynamic>> get receivedEvents {
    return _fixture.events
        .where((e) => e.direction == 'received')
        .map((e) => e.payload)
        .toList();
  }

  /// Returns all sent events (client -> server).
  List<Map<String, dynamic>> get sentEvents {
    return _fixture.events
        .where((e) => e.direction == 'sent')
        .map((e) => e.payload)
        .toList();
  }

  /// Returns received events of a specific type.
  List<Map<String, dynamic>> receivedEventsOfType(String type) {
    return receivedEvents.where((e) => e['type'] == type).toList();
  }

  /// Returns sent events of a specific type.
  List<Map<String, dynamic>> sentEventsOfType(String type) {
    return sentEvents.where((e) => e['type'] == type).toList();
  }
}

final class RealtimeFixture {
  final String scenario;
  final String recordedAt;
  final int eventCount;
  final List<RealtimeFixtureEvent> events;

  RealtimeFixture({
    required this.scenario,
    required this.recordedAt,
    required this.eventCount,
    required this.events,
  });

  factory RealtimeFixture.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? [];
    final events = eventsJson
        .whereType<Map<String, dynamic>>()
        .map(RealtimeFixtureEvent.fromJson)
        .toList();

    return RealtimeFixture(
      scenario: json['scenario'] as String? ?? '',
      recordedAt: json['recorded_at'] as String? ?? '',
      eventCount: json['event_count'] as int? ?? 0,
      events: events,
    );
  }
}

final class RealtimeFixtureEvent {
  final String direction; // 'sent' or 'received'
  final String timestamp;
  final Map<String, dynamic> payload;

  RealtimeFixtureEvent({
    required this.direction,
    required this.timestamp,
    required this.payload,
  });

  factory RealtimeFixtureEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeFixtureEvent(
      direction: json['direction'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
