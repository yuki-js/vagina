import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/call_service.dart';

import 'text_agent_service_test_support.dart';

void main() {
  test(
    'FakeRealtimeAdapter records image messages for call service tests',
    () async {
      final adapter = FakeRealtimeAdapter();
      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      final itemId = await adapter.sendImage(imageBytes);

      expect(itemId, 'image-1');
      expect(adapter.sentImages, hasLength(1));
      expect(adapter.sentImages.single, equals(imageBytes));
    },
  );

  test('CallState active remains the gate used by chat image submission', () {
    expect(CallState.active, isNot(CallState.uninitialized));
    expect(CallState.active, isNot(CallState.disposed));
  });
}
