import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/generated/models/speed_dial.dart';
import 'package:vagina/api/generated/models/speed_dial_reasoning_effort.dart';

import 'package:vagina/api/generated/models/speed_dial_create_request_reasoning_effort.dart';
import 'package:vagina/api/generated/models/speed_dial_update_request.dart';
import 'package:vagina/api/generated/models/speed_dial_update_request_reasoning_effort.dart';

void main() {
  group('SpeedDial generated model', () {
    test('parses JSON-decoded enabledTools as a typed map', () {
      final decoded =
          jsonDecode('''
        {
          "id": "default",
          "name": "Default",
          "systemPrompt": "You are a helpful AI assistant.",
          "voice": "alloy",
          "voiceAgentId": "voice-agent-prod",
          "reasoningEffort": "off",
          "toolChoiceRequired": false,
          "enabledTools": {
            "document_read": true,
            "document_patch": false
          }
        }
      ''')
              as Map<String, dynamic>;

      final speedDial = SpeedDial.fromJson(decoded);

      expect(speedDial.enabledTools, <String, bool>{
        'document_read': true,
        'document_patch': false,
      });
    });

    test('parses reasoning effort and tool choice fields', () {
      final decoded =
          jsonDecode('''
        {
          "id": "default",
          "name": "Default",
          "systemPrompt": "You are a helpful AI assistant.",
          "voice": "alloy",
          "voiceAgentId": "voice-agent-prod",
          "reasoningEffort": "off",
          "toolChoiceRequired": false,
          "enabledTools": {}
        }
      ''')
              as Map<String, dynamic>;

      final speedDial = SpeedDial.fromJson(decoded);

      expect(speedDial.reasoningEffort, SpeedDialReasoningEffort.off);
      expect(speedDial.toolChoiceRequired, isFalse);
      expect(speedDial.toJson()['reasoningEffort'], 'off');
      expect(speedDial.toJson()['toolChoiceRequired'], isFalse);
    });

    test('accepts legacy uppercase reasoning effort but emits canonical lowercase', () {
      final decoded =
          jsonDecode('''
        {
          "id": "default",
          "name": "Default",
          "systemPrompt": "You are a helpful AI assistant.",
          "voice": "alloy",
          "voiceAgentId": "voice-agent-prod",
          "reasoningEffort": "OFF",
          "toolChoiceRequired": false,
          "enabledTools": {}
        }
      ''')
              as Map<String, dynamic>;

      final speedDial = SpeedDial.fromJson(decoded);

      expect(speedDial.reasoningEffort, SpeedDialReasoningEffort.off);
      expect(speedDial.toJson()['reasoningEffort'], 'off');
    });

    test('request enum parsers accept legacy uppercase values', () {
      expect(
        SpeedDialCreateRequestReasoningEffort.fromJsonValue('OFF'),
        SpeedDialCreateRequestReasoningEffort.off,
      );

      final updateRequest = SpeedDialUpdateRequest.fromJson(<String, dynamic>{
        'name': 'Default',
        'systemPrompt': 'You are a helpful AI assistant.',
        'voice': 'alloy',
        'voiceAgentId': 'voice-agent-prod',
        'reasoningEffort': 'OFF',
        'toolChoiceRequired': false,
        'enabledTools': <String, dynamic>{},
      });

      expect(
        updateRequest.reasoningEffort,
        SpeedDialUpdateRequestReasoningEffort.off,
      );
      expect(updateRequest.toJson()['reasoningEffort'], 'off');
    });
  });
}
