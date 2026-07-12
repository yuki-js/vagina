import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/speed_dial.dart';

void main() {
  group('SpeedDial voiceAgentId', () {
    test('default speed dial uses the default voice agent id', () {
      final speedDial = SpeedDial.defaultSpeedDial;

      expect(speedDial.voiceAgentId, SpeedDial.defaultVoiceAgentId);
      expect(speedDial.toJson()['voiceAgentId'], SpeedDial.defaultVoiceAgentId);
    });

    test('round-trips voiceAgentId through JSON', () {
      final speedDial = SpeedDial(
        id: 'custom',
        name: 'Custom',
        systemPrompt: 'You are custom.',
        voice: 'alloy',
        voiceAgentId: 'voice-agent-prod-cc',
      );

      final restored = SpeedDial.fromJson(speedDial.toJson());

      expect(restored.voiceAgentId, 'voice-agent-prod-cc');
    });

    test('falls back to default voiceAgentId for legacy local JSON', () {
      final speedDial = SpeedDial.fromJson({
        'id': 'legacy',
        'name': 'Legacy',
        'systemPrompt': 'You are legacy.',
        'voice': 'alloy',
        'enabledTools': <String, bool>{},
      });

      expect(speedDial.voiceAgentId, SpeedDial.defaultVoiceAgentId);
    });
  });

  group('SpeedDial reasoningEffort', () {
    test(
      'accepts legacy uppercase local JSON but emits canonical lowercase',
      () {
        final speedDial = SpeedDial.fromJson({
          'id': 'legacy',
          'name': 'Legacy',
          'systemPrompt': 'You are legacy.',
          'voice': 'alloy',
          'voiceAgentId': SpeedDial.defaultVoiceAgentId,
          'enabledTools': <String, bool>{},
          'reasoningEffort': 'OFF',
        });

        expect(speedDial.reasoningEffort, SpeedDialReasoningEffort.off);
        expect(speedDial.toJson()['reasoningEffort'], 'off');
      },
    );
  });
}
