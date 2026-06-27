import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/generated/models/speed_dial.dart';

void main() {
  group('SpeedDial generated model', () {
    test('parses JSON-decoded enabledTools as a typed map', () {
      final decoded = jsonDecode('''
        {
          "id": "default",
          "name": "Default",
          "systemPrompt": "You are a helpful AI assistant.",
          "voice": "alloy",
          "enabledTools": {
            "document_read": true,
            "document_patch": false
          }
        }
      ''') as Map<String, dynamic>;

      final speedDial = SpeedDial.fromJson(decoded);

      expect(speedDial.enabledTools, <String, bool>{
        'document_read': true,
        'document_patch': false,
      });
    });
  });
}
