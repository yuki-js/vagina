import 'package:vagina/models/speed_dial.dart';

/// Repository for managing speed dial data
abstract class SpeedDialRepository {
  /// Create a speed dial entry and return the server/generated persisted entry.
  Future<SpeedDial> create({
    required String name,
    required String systemPrompt,
    String? description,
    String? iconEmoji,
    String voice = 'alloy',
    String voiceAgentId = SpeedDial.defaultVoiceAgentId,
    Map<String, bool> enabledTools = const {},
    bool toolChoiceRequired = false,
  });

  /// Get all speed dials
  Future<List<SpeedDial>> getAll();

  /// Get a specific speed dial by ID
  Future<SpeedDial?> getById(String id);

  /// Update a speed dial
  Future<bool> update(SpeedDial speedDial);

  /// Delete a speed dial
  Future<bool> delete(String id);
}
