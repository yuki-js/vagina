import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_thread_projector.dart';

void main() {
  test(
    'add_item with previousItemId inserts after parent in client projection',
    () {
      final thread = RealtimeThread(id: 'thread-1');
      final projector = VhrpThreadProjector();

      projector.applyPatch(
        ThreadPatchMsg(
          ops: <ThreadPatchOp>[
            AddItemOp(
              item: <String, Object?>{
                'id': 'user-1',
                'type': 'message',
                'role': 'user',
                'status': 'completed',
              },
            ),
            AddItemOp(
              item: <String, Object?>{
                'id': 'user-2',
                'type': 'message',
                'role': 'user',
                'status': 'completed',
              },
            ),
            AddItemOp(
              previousItemId: 'user-1',
              item: <String, Object?>{
                'id': 'assistant-1',
                'type': 'message',
                'role': 'assistant',
                'status': 'completed',
              },
            ),
          ],
        ),
        thread,
      );

      expect(thread.items.map((item) => item.id).toList(), <String>[
        'user-1',
        'assistant-1',
        'user-2',
      ]);
    },
  );
}
