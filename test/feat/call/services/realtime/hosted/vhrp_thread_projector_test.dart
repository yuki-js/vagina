// Tests for VhrpThreadProjector — Step 4 thread projection logic.
//
// Testing philosophy (handoff doc §9.3):
//   Each test begins with a contract comment stating:
//     - which user-visible behaviour or protocol invariant is being guarded, and
//     - what breaks for the user if this test goes red.
//
// Test coverage targets (per task requirements):
//   T1  add_item → put_part(text) → append_text × 2 → set_status(completed)
//       — assistant message is correctly assembled in real-time.
//   T2  add_item idempotency: second add_item with same id merges, not duplicates.
//   T3  functionCall set_field (callId/name/arguments) + functionCallOutput.
//   T4  thread.snapshot replaces local thread wholesale.
//   T5  append_transcript / replace_transcript act on audio transcript only.
//   T6  desync: op targeting non-existent itemId returns desync result.
//   T7  desync: UnknownOp in patch returns desync result.
//   T8  adapter integration: desync → thread.sync.request sent over transport.

import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_thread_projector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared test helpers
// ─────────────────────────────────────────────────────────────────────────────

const _projector = VhrpThreadProjector();

/// Returns a fresh empty [RealtimeThread] for use as a starting point.
RealtimeThread _emptyThread({String id = 'thread-1'}) =>
    RealtimeThread(id: id);

/// Builds an [AddItemOp] from a plain Dart map.
AddItemOp _addItemOp(Map<String, Object?> item) => AddItemOp(item: item);

/// Builds a minimal assistant message item map.
Map<String, Object?> _assistantMsgMap(String id, {String status = 'in_progress'}) => {
      'id': id,
      'type': 'message',
      'role': 'assistant',
      'status': status,
      'content': <Object?>[],
    };

/// Builds a minimal user message item map.
Map<String, Object?> _userMsgMap(String id) => {
      'id': id,
      'type': 'message',
      'role': 'user',
      'status': 'completed',
      'content': <Object?>[],
    };

/// Builds a minimal functionCall item map.
Map<String, Object?> _functionCallMap(String id) => {
      'id': id,
      'type': 'functionCall',
      'role': 'assistant',
      'status': 'in_progress',
      'content': <Object?>[],
    };

/// Builds a minimal functionCallOutput item map.
Map<String, Object?> _functionCallOutputMap(String id, String callId) => {
      'id': id,
      'type': 'functionCallOutput',
      'role': 'assistant',
      'status': 'completed',
      'callId': callId,
      'content': <Object?>[],
    };

/// Applies a list of [ThreadPatchOp]s to [thread] via the projector and
/// returns the final [ProjectResult].
ProjectResult _patch(RealtimeThread thread, List<ThreadPatchOp> ops) =>
    _projector.applyPatch(ThreadPatchMsg(ops: ops), thread);

// ─────────────────────────────────────────────────────────────────────────────
// T1 — Full assistant message assembly sequence
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('T1 — add_item → put_part(text) → append_text × 2 → set_status', () {
    test(
      // Contract: as the AI generates a text response, the client must
      // accumulate delta text so the user can read each token as it arrives.
      // The item must transition to completed at the end, so the UI knows
      // the response is final.
      'assembles an assistant message item with text content in real-time',
      () {
        final thread = _emptyThread();

        final result = _patch(thread, [
          _addItemOp(_assistantMsgMap('item_a')),
          PutPartOp(
            itemId: 'item_a',
            contentIndex: 0,
            part: {'type': 'text', 'isDone': false},
          ),
          AppendTextOp(itemId: 'item_a', contentIndex: 0, delta: 'Hello'),
          AppendTextOp(itemId: 'item_a', contentIndex: 0, delta: ', world'),
          SetStatusOp(itemId: 'item_a', status: 'completed'),
        ]);

        expect(result.desync, isFalse, reason: 'No desync expected');
        expect(thread.items, hasLength(1));

        final item = thread.items.first;
        expect(item.id, 'item_a');
        expect(item.type, RealtimeThreadItemType.message);
        expect(item.role, RealtimeThreadItemRole.assistant);
        expect(item.status, RealtimeThreadItemStatus.completed);
        expect(item.content, hasLength(1));

        final textPart = item.content.first as RealtimeThreadTextPart;
        expect(textPart.text, 'Hello, world');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T2 — add_item idempotency / merge
  // ─────────────────────────────────────────────────────────────────────────

  group('T2 — add_item idempotency: same id twice merges, not duplicates', () {
    test(
      // Contract: when a user sends a message, the client pre-assigns an
      // item id (step 8 pre-numbering) and adds the item locally.  The server
      // then sends an add_item with the same id in a thread.patch.  If the
      // projector duplicated the item, the user would see two copies of the
      // same message in the conversation.  Merging prevents this.
      'second add_item with same id does not duplicate the item',
      () {
        final thread = _emptyThread();

        // Simulate the client having pre-added a user item.
        thread.addItem(RealtimeThreadItem(
          id: 'pre-item-1',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.user,
          status: RealtimeThreadItemStatus.inProgress,
        ));

        // Server sends add_item with the same id (canonical form).
        final result = _patch(thread, [
          _addItemOp({
            'id': 'pre-item-1',
            'type': 'message',
            'role': 'user',
            'status': 'completed', // server sets it to completed
            'content': <Object?>[],
          }),
        ]);

        expect(result.desync, isFalse);
        // Still only one item — not duplicated.
        expect(thread.items, hasLength(1));
        final item = thread.items.first;
        expect(item.id, 'pre-item-1');
        // Status was updated from inProgress → completed via merge.
        expect(item.status, RealtimeThreadItemStatus.completed);
      },
    );

    test(
      // Contract: when merging a pre-numbered item, any content parts the
      // client already accumulated (e.g., for a user's text message) must not
      // be wiped by the server's add_item.
      'merge does not erase existing content parts',
      () {
        final thread = _emptyThread();

        final existingItem = RealtimeThreadItem(
          id: 'pre-item-2',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.user,
          status: RealtimeThreadItemStatus.inProgress,
        );
        existingItem.addContentPart(
          RealtimeThreadTextPart(text: 'existing text'),
        );
        thread.addItem(existingItem);

        // Server add_item has no content — merge must keep existing content.
        _patch(thread, [
          _addItemOp({
            'id': 'pre-item-2',
            'type': 'message',
            'role': 'user',
            'status': 'completed',
            'content': <Object?>[],
          }),
        ]);

        final item = thread.items.first;
        expect(item.content, hasLength(1),
            reason: 'Existing content must be preserved on merge');
        expect((item.content.first as RealtimeThreadTextPart).text, 'existing text');
      },
    );

    test(
      // Contract: when a server add_item has content and the existing item
      // has none, the incoming content is applied so the conversation is
      // populated correctly on replay / snapshot edge cases.
      'merge adds incoming content parts when existing item has none',
      () {
        final thread = _emptyThread();
        thread.addItem(RealtimeThreadItem(
          id: 'pre-item-3',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.user,
          status: RealtimeThreadItemStatus.inProgress,
        ));

        _patch(thread, [
          _addItemOp({
            'id': 'pre-item-3',
            'type': 'message',
            'role': 'user',
            'status': 'completed',
            'content': [
              {'type': 'text', 'text': 'server text', 'isDone': true},
            ],
          }),
        ]);

        final item = thread.items.first;
        expect(item.content, hasLength(1));
        expect((item.content.first as RealtimeThreadTextPart).text, 'server text');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T3 — functionCall + functionCallOutput
  // ─────────────────────────────────────────────────────────────────────────

  group('T3 — functionCall and functionCallOutput construction', () {
    test(
      // Contract: when the AI calls a function, the client must record
      // callId, name, and arguments so the host app can execute the correct
      // function with the right parameters and return the result.
      'set_field (callId/name/arguments) populates functionCall fields',
      () {
        final thread = _emptyThread();

        _patch(thread, [
          _addItemOp(_functionCallMap('fc-1')),
          SetFieldOp(itemId: 'fc-1', field: 'callId', value: 'call_42'),
          SetFieldOp(itemId: 'fc-1', field: 'name', value: 'get_weather'),
          SetFieldOp(
            itemId: 'fc-1',
            field: 'arguments',
            value: '{"city":"Tokyo"}',
          ),
          SetStatusOp(itemId: 'fc-1', status: 'completed'),
        ]);

        final item = thread.findItem('fc-1')!;
        expect(item.type, RealtimeThreadItemType.functionCall);
        expect(item.callId, 'call_42');
        expect(item.name, 'get_weather');
        expect(item.arguments, '{"city":"Tokyo"}');
        expect(item.status, RealtimeThreadItemStatus.completed);
      },
    );

    test(
      // Contract: when the app returns the result of a tool call, the thread
      // must show a functionCallOutput item with the same callId so the AI
      // can correlate the result to the original request.
      'add_item functionCallOutput creates item with correct callId',
      () {
        final thread = _emptyThread();

        _patch(thread, [
          _addItemOp(_functionCallOutputMap('fco-1', 'call_42')),
          SetFieldOp(
            itemId: 'fco-1',
            field: 'output',
            value: '{"temp":"20C"}',
          ),
          SetFieldOp(
            itemId: 'fco-1',
            field: 'toolOutputDisposition',
            value: 'success',
          ),
        ]);

        final item = thread.findItem('fco-1')!;
        expect(item.type, RealtimeThreadItemType.functionCallOutput);
        expect(item.callId, 'call_42');
        expect(item.output, '{"temp":"20C"}');
        expect(
          item.toolOutputDisposition,
          RealtimeToolOutputDisposition.success,
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T4 — snapshot replaces local thread
  // ─────────────────────────────────────────────────────────────────────────

  group('T4 — thread.snapshot replaces local thread wholesale', () {
    test(
      // Contract: on reconnect or desync recovery, the server sends a full
      // snapshot.  Any items the client had before must be discarded and
      // replaced by the snapshot items, so the displayed conversation matches
      // the authoritative server state exactly.
      'applySnapshot returns a new thread with snapshot items; old items gone',
      () {
        // Simulate a thread with stale data.
        final staleThread = RealtimeThread(id: 'old-thread');
        staleThread.addItem(RealtimeThreadItem(
          id: 'stale-item',
          type: RealtimeThreadItemType.message,
        ));

        final snapshotMsg = ThreadSnapshotMsg(
          threadId: 'new-thread-id',
          conversationId: 'conv-99',
          items: [
            _assistantMsgMap('snap-item-1', status: 'completed'),
            _userMsgMap('snap-item-2'),
          ],
        );

        final newThread = _projector.applySnapshot(snapshotMsg);

        // New thread has the snapshot's id and conversationId.
        expect(newThread.id, 'new-thread-id');
        expect(newThread.conversationId, 'conv-99');

        // New thread has exactly the snapshot items.
        expect(newThread.items, hasLength(2));
        expect(newThread.findItem('snap-item-1'), isNotNull);
        expect(newThread.findItem('snap-item-2'), isNotNull);

        // Old stale item is absent (old thread reference unchanged but
        // the returned reference is different — caller replaces _thread).
        expect(staleThread.findItem('stale-item'), isNotNull,
            reason: 'staleThread itself is unchanged by applySnapshot');
        expect(newThread.findItem('stale-item'), isNull,
            reason: 'Snapshot does not include the stale item');
      },
    );

    test(
      // Contract: snapshot items include content parts (e.g., text already
      // written before reconnect) so users can see the conversation history
      // immediately after reconnecting.
      'snapshot with content parts builds items with those parts',
      () {
        final msg = ThreadSnapshotMsg(
          threadId: 't-1',
          conversationId: null,
          items: [
            {
              'id': 'item-with-text',
              'type': 'message',
              'role': 'assistant',
              'status': 'completed',
              'content': [
                {'type': 'text', 'text': 'Hello', 'isDone': true},
              ],
            },
          ],
        );

        final thread = _projector.applySnapshot(msg);
        final item = thread.findItem('item-with-text')!;
        expect(item.content, hasLength(1));
        final part = item.content.first as RealtimeThreadTextPart;
        expect(part.text, 'Hello');
        expect(part.isDone, isTrue);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T5 — audio transcript ops
  // ─────────────────────────────────────────────────────────────────────────

  group('T5 — append_transcript / replace_transcript on audio parts', () {
    test(
      // Contract: the user wants to read a transcript of the AI's spoken
      // response.  append_transcript must accumulate the text delta by delta
      // without touching the (empty-at-this-layer) audioChunks list.
      'append_transcript updates transcript and leaves audioChunks empty',
      () {
        final thread = _emptyThread();

        _patch(thread, [
          _addItemOp(_assistantMsgMap('ai-audio')),
          PutPartOp(
            itemId: 'ai-audio',
            contentIndex: 0,
            part: {'type': 'audio', 'isDone': false},
          ),
          AppendTranscriptOp(
            itemId: 'ai-audio',
            contentIndex: 0,
            delta: 'Hello',
          ),
          AppendTranscriptOp(
            itemId: 'ai-audio',
            contentIndex: 0,
            delta: ' world',
          ),
        ]);

        final item = thread.findItem('ai-audio')!;
        final audioPart = item.content.first as RealtimeThreadAudioPart;

        expect(audioPart.transcript, 'Hello world',
            reason: 'transcript must accumulate deltas');
        expect(audioPart.audioChunks, isEmpty,
            reason: 'audioChunks must be untouched by transcript ops (§5.6)');
      },
    );

    test(
      // Contract: replace_transcript is used when the server sends a final
      // corrected transcript.  It must overwrite any partial transcript so
      // the user reads the accurate final version.
      'replace_transcript overwrites partial transcript; audioChunks untouched',
      () {
        final thread = _emptyThread();

        _patch(thread, [
          _addItemOp(_assistantMsgMap('ai-audio-2')),
          PutPartOp(
            itemId: 'ai-audio-2',
            contentIndex: 0,
            part: {'type': 'audio', 'isDone': false},
          ),
          AppendTranscriptOp(
            itemId: 'ai-audio-2',
            contentIndex: 0,
            delta: 'partial',
          ),
          ReplaceTranscriptOp(
            itemId: 'ai-audio-2',
            contentIndex: 0,
            text: 'Final transcript',
          ),
        ]);

        final item = thread.findItem('ai-audio-2')!;
        final audioPart = item.content.first as RealtimeThreadAudioPart;
        expect(audioPart.transcript, 'Final transcript');
        expect(audioPart.audioChunks, isEmpty);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T6 — desync: missing target item
  // ─────────────────────────────────────────────────────────────────────────

  group('T6 — desync when op targets non-existent item', () {
    final desyncOps = <String, ThreadPatchOp>{
      'set_status':
          SetStatusOp(itemId: 'ghost', status: 'completed'),
      'set_role':
          SetRoleOp(itemId: 'ghost', role: 'assistant'),
      'set_field':
          SetFieldOp(itemId: 'ghost', field: 'callId', value: 'x'),
      'put_part':
          PutPartOp(
            itemId: 'ghost',
            contentIndex: 0,
            part: {'type': 'text', 'isDone': false},
          ),
      'append_text':
          AppendTextOp(itemId: 'ghost', contentIndex: 0, delta: 'hi'),
      'replace_text':
          ReplaceTextOp(itemId: 'ghost', contentIndex: 0, text: 'hi'),
      'append_transcript':
          AppendTranscriptOp(itemId: 'ghost', contentIndex: 0, delta: 'hi'),
      'replace_transcript':
          ReplaceTranscriptOp(itemId: 'ghost', contentIndex: 0, text: 'hi'),
    };

    for (final entry in desyncOps.entries) {
      test(
        // Contract: if a patch op references an item the client has never
        // seen, the local thread is out of sync with the server.  The client
        // must signal desync so the adapter can request a fresh snapshot,
        // ensuring the user never sees an inconsistent conversation state.
        '${entry.key} on non-existent item signals desync',
        () {
          final thread = _emptyThread();
          final result = _patch(thread, [entry.value]);
          expect(result.desync, isTrue,
              reason: '${entry.key} targeting missing item must desync');
          expect(result.desyncReason, isNotNull);
        },
      );
    }

    test(
      // Contract: remaining ops after the first failing op must NOT be
      // applied, because continuing would corrupt the local state further.
      'ops after the first failing op are not applied',
      () {
        final thread = _emptyThread();
        // This op will succeed.
        thread.addItem(RealtimeThreadItem(
          id: 'good-item',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.assistant,
          status: RealtimeThreadItemStatus.inProgress,
        ));

        final result = _patch(thread, [
          SetStatusOp(itemId: 'ghost', status: 'completed'),   // FAILS → desync
          SetStatusOp(itemId: 'good-item', status: 'completed'), // must NOT run
        ]);

        expect(result.desync, isTrue);
        // good-item must still be inProgress (second op was not applied).
        final item = thread.findItem('good-item')!;
        expect(item.status, RealtimeThreadItemStatus.inProgress);
      },
    );

    test(
      // Contract: remove_item on a non-existent id must be silently tolerated
      // (idempotent delete) — it is NOT a desync condition.  The server may
      // legitimately send a remove for an item the client already removed.
      'remove_item on non-existent item is NOT a desync',
      () {
        final thread = _emptyThread();
        final result = _patch(thread, [
          RemoveItemOp(itemId: 'already-gone'),
        ]);
        expect(result.desync, isFalse,
            reason: 'Idempotent remove must not trigger desync');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T7 — desync: UnknownOp
  // ─────────────────────────────────────────────────────────────────────────

  group('T7 — desync when patch contains UnknownOp', () {
    test(
      // Contract: if the server adds a new patch op the client does not
      // understand, the client cannot safely apply the remaining ops because
      // the thread state may be wrong.  Desync must be triggered so the user
      // always sees a consistent conversation.
      'UnknownOp in patch signals desync',
      () {
        final thread = _emptyThread();
        thread.addItem(RealtimeThreadItem(
          id: 'item-x',
          type: RealtimeThreadItemType.message,
        ));

        final result = _patch(thread, [
          UnknownOp(unknownOp: 'future_op', rawOp: {'op': 'future_op'}),
        ]);

        expect(result.desync, isTrue);
        expect(result.desyncReason, contains('future_op'));
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // T8 — adapter integration: desync sends thread.sync.request
  // ─────────────────────────────────────────────────────────────────────────

  group('T8 — adapter wiring: desync triggers thread.sync.request', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = VhrpRealtimeAdapter(
        transport: fake,
        tokenProvider: () async => 'test-token',
        urlResolver: (_) =>
            Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
      );
    });

    tearDown(() async {
      await adapter.dispose();
      await fake.reset();
    });

    /// Injects a [SessionReadyMsg] CBOR frame into [fake].
    void injectSessionReady() {
      final frame = cbor.encode(CborMap({
        CborString('type'): CborString('session.ready'),
        CborString('body'): CborMap({
          CborString('sessionId'): CborString('s-1'),
          CborString('threadId'): CborString('t-1'),
          CborString('conversationId'): CborString('c-1'),
          CborString('capabilities'):
              CborMap({CborString('extensions'): CborList([])}),
        }),
      }));
      fake.injectInbound(Uint8List.fromList(frame));
    }

    /// Injects a [ThreadPatchMsg] CBOR frame that targets a non-existent item.
    void injectDesyncPatch() {
      final frame = cbor.encode(CborMap({
        CborString('type'): CborString('thread.patch'),
        CborString('body'): CborMap({
          CborString('ops'): CborList([
            CborMap({
              CborString('op'): CborString('set_status'),
              CborString('itemId'): CborString('ghost-item'),
              CborString('status'): CborString('completed'),
            }),
          ]),
        }),
      }));
      fake.injectInbound(Uint8List.fromList(frame));
    }

    /// Injects a [ThreadPatchMsg] containing an [UnknownOp].
    void injectUnknownOpPatch() {
      final frame = cbor.encode(CborMap({
        CborString('type'): CborString('thread.patch'),
        CborString('body'): CborMap({
          CborString('ops'): CborList([
            CborMap({
              CborString('op'): CborString('totally_unknown_op'),
              CborString('itemId'): CborString('some-item'),
            }),
          ]),
        }),
      }));
      fake.injectInbound(Uint8List.fromList(frame));
    }

    /// Connects the adapter (blocks until session.ready is processed).
    Future<void> connect() async {
      final future = adapter.connect(
        HostedVoiceAgentApiConfig(modelId: 'test-model'),
      );
      await Future<void>.delayed(Duration.zero);
      injectSessionReady();
      await future;
      // Allow microtask queue to drain so session.ready is dispatched.
      await Future<void>.delayed(Duration.zero);
    }

    /// Returns the type field of the last C2S message sent over [fake].
    String? lastSentType() {
      if (fake.sentBytes.isEmpty) return null;
      final decoded = cbor.decode(fake.sentBytes.last) as CborMap;
      return (decoded[CborString('type')] as CborString?)?.toString();
    }

    /// Returns the body.reason of the last C2S message sent over [fake].
    String? lastSentBodyReason() {
      if (fake.sentBytes.isEmpty) return null;
      final decoded = cbor.decode(fake.sentBytes.last) as CborMap;
      final body = decoded[CborString('body')] as CborMap?;
      return (body?[CborString('reason')] as CborString?)?.toString();
    }

    test(
      // Contract: when the local thread gets out of sync with the server (an
      // op targets a missing item), the adapter must proactively request a
      // fresh snapshot so the user never sees a conversation frozen in a
      // broken intermediate state.
      'desync via missing-item op causes thread.sync.request to be sent',
      () async {
        await connect();
        final sentCountBefore = fake.sentBytes.length;

        injectDesyncPatch();
        await Future<void>.delayed(Duration.zero);

        // At least one new message must have been sent after the patch.
        expect(fake.sentBytes.length, greaterThan(sentCountBefore),
            reason: 'thread.sync.request must be sent on desync');
        expect(lastSentType(), 'thread.sync.request',
            reason: 'The recovery message must be thread.sync.request');
      },
    );

    test(
      // Contract: same as above but triggered by an UnknownOp — even a
      // completely foreign op type must cause a resync so the user sees an
      // up-to-date conversation after a server protocol upgrade.
      'desync via UnknownOp causes thread.sync.request to be sent',
      () async {
        await connect();
        final sentCountBefore = fake.sentBytes.length;

        injectUnknownOpPatch();
        await Future<void>.delayed(Duration.zero);

        expect(fake.sentBytes.length, greaterThan(sentCountBefore));
        expect(lastSentType(), 'thread.sync.request');
      },
    );

    test(
      // Contract: thread.sync.request must carry a non-empty reason field so
      // server-side diagnostics can identify what triggered the resync.
      'thread.sync.request includes a non-empty reason field',
      () async {
        await connect();

        injectDesyncPatch();
        await Future<void>.delayed(Duration.zero);

        final reason = lastSentBodyReason();
        expect(reason, isNotNull);
        expect(reason, isNotEmpty);
      },
    );

    test(
      // Contract: a valid patch (all ops applicable) must fire threadUpdates
      // so the UI re-renders the conversation with the latest content.
      'valid patch fires threadUpdates and does NOT send thread.sync.request',
      () async {
        await connect();

        // First inject an add_item so the item exists.
        final addFrame = cbor.encode(CborMap({
          CborString('type'): CborString('thread.patch'),
          CborString('body'): CborMap({
            CborString('ops'): CborList([
              CborMap({
                CborString('op'): CborString('add_item'),
                CborString('item'): CborMap({
                  CborString('id'): CborString('real-item'),
                  CborString('type'): CborString('message'),
                  CborString('role'): CborString('assistant'),
                  CborString('status'): CborString('in_progress'),
                  CborString('content'): CborList([]),
                }),
              }),
            ]),
          }),
        }));
        fake.injectInbound(Uint8List.fromList(addFrame));
        await Future<void>.delayed(Duration.zero);

        final sentCountAfterAdd = fake.sentBytes.length;

        // Inject a valid set_status.
        final patchFrame = cbor.encode(CborMap({
          CborString('type'): CborString('thread.patch'),
          CborString('body'): CborMap({
            CborString('ops'): CborList([
              CborMap({
                CborString('op'): CborString('set_status'),
                CborString('itemId'): CborString('real-item'),
                CborString('status'): CborString('completed'),
              }),
            ]),
          }),
        }));

        final threadUpdates = <RealtimeThread>[];
        final sub = adapter.threadUpdates.listen(threadUpdates.add);
        fake.injectInbound(Uint8List.fromList(patchFrame));
        await Future<void>.delayed(Duration.zero);

        // No extra message should be sent for a valid patch.
        expect(fake.sentBytes.length, equals(sentCountAfterAdd),
            reason:
                'thread.sync.request must NOT be sent for a valid patch');
        expect(threadUpdates, isNotEmpty,
            reason: 'threadUpdates must fire after a valid patch');

        await sub.cancel();
      },
    );

    test(
      // Contract: when a snapshot arrives the adapter must update its thread
      // reference and emit a threadUpdates event so the UI replaces the old
      // conversation with the freshly synced one.
      'thread.snapshot replaces thread and fires threadUpdates',
      () async {
        await connect();

        final snapshotFrame = cbor.encode(CborMap({
          CborString('type'): CborString('thread.snapshot'),
          CborString('body'): CborMap({
            CborString('threadId'): CborString('snap-thread'),
            CborString('conversationId'): CborString('snap-conv'),
            CborString('items'): CborList([
              CborMap({
                CborString('id'): CborString('snap-item-1'),
                CborString('type'): CborString('message'),
                CborString('role'): CborString('assistant'),
                CborString('status'): CborString('completed'),
                CborString('content'): CborList([]),
              }),
            ]),
          }),
        }));

        final updates = <RealtimeThread>[];
        final sub = adapter.threadUpdates.listen(updates.add);

        fake.injectInbound(Uint8List.fromList(snapshotFrame));
        await Future<void>.delayed(Duration.zero);

        expect(updates, isNotEmpty, reason: 'threadUpdates must fire on snapshot');
        expect(adapter.thread.id, 'snap-thread',
            reason: 'adapter.thread must be replaced with the snapshot thread');
        expect(adapter.thread.findItem('snap-item-1'), isNotNull);

        await sub.cancel();
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Additional projector op coverage
  // ─────────────────────────────────────────────────────────────────────────

  group('Additional op coverage', () {
    test(
      // Contract: replace_text lets the server send a fully-corrected version
      // of a text part so the user never reads a garbled final message.
      'replace_text replaces text part content',
      () {
        final thread = _emptyThread();
        _patch(thread, [
          _addItemOp(_assistantMsgMap('item-rt')),
          PutPartOp(
            itemId: 'item-rt',
            contentIndex: 0,
            part: {'type': 'text', 'isDone': false},
          ),
          AppendTextOp(itemId: 'item-rt', contentIndex: 0, delta: 'partial'),
          ReplaceTextOp(itemId: 'item-rt', contentIndex: 0, text: 'full text'),
        ]);

        final part = thread.findItem('item-rt')!.content.first
            as RealtimeThreadTextPart;
        expect(part.text, 'full text');
      },
    );

    test(
      // Contract: set_conversation_id must propagate so the app can correctly
      // associate conversation-scoped operations and analytics.
      'set_conversation_id updates thread.conversationId',
      () {
        final thread = _emptyThread();
        _patch(thread, [
          SetConversationIdOp(conversationId: 'conv-new'),
        ]);
        expect(thread.conversationId, 'conv-new');
      },
    );

    test(
      // Contract: remove_item removes the item so the user no longer sees it
      // in the conversation (e.g., an interrupted generation that should be
      // discarded).
      'remove_item removes an existing item',
      () {
        final thread = _emptyThread();
        thread.addItem(RealtimeThreadItem(
          id: 'to-remove',
          type: RealtimeThreadItemType.message,
        ));
        expect(thread.items, hasLength(1));

        _patch(thread, [RemoveItemOp(itemId: 'to-remove')]);

        expect(thread.items, isEmpty,
            reason: 'Item must be removed from the thread');
      },
    );

    test(
      // Contract: set_role allows the server to correct or clarify an item's
      // role mid-stream so the UI renders it with the correct sender label.
      'set_role updates item role',
      () {
        final thread = _emptyThread();
        thread.addItem(RealtimeThreadItem(
          id: 'item-role',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.assistant,
        ));

        _patch(thread, [SetRoleOp(itemId: 'item-role', role: 'user')]);

        expect(
          thread.findItem('item-role')!.role,
          RealtimeThreadItemRole.user,
        );
      },
    );

    test(
      // Contract: put_part with image type creates a RealtimeThreadImagePart
      // so user-shared images are displayed in the conversation.
      'put_part with image type creates RealtimeThreadImagePart',
      () {
        final thread = _emptyThread();
        thread.addItem(RealtimeThreadItem(
          id: 'img-item',
          type: RealtimeThreadItemType.message,
          role: RealtimeThreadItemRole.user,
        ));

        _patch(thread, [
          PutPartOp(
            itemId: 'img-item',
            contentIndex: 0,
            part: {
              'type': 'image',
              'imageUrl': 'https://example.com/img.png',
              'detail': 'high',
            },
          ),
        ]);

        final part =
            thread.findItem('img-item')!.content.first as RealtimeThreadImagePart;
        expect(part.imageUrl, 'https://example.com/img.png');
        expect(part.detail, 'high');
      },
    );
  });
}
