// Tests for VhrpRealtimeAdapter — Step 8: interrupt, cancelFunctionCalls,
// resume reconnect, desync→recovery integration.
//
// Contract assertions declared per §9.3 of the handoff doc.
// Each test carries a "Use-case / contract" comment stating:
//   • What user-visible behaviour this test protects.
//   • Which section of the handoff doc / VHRP spec is exercised.

import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared test helpers
// ─────────────────────────────────────────────────────────────────────────────

const String _testToken = 'test-jwt-token-resume';
const String _testModelId = 'vagina-v1-turbo';
final _testConfig = HostedVoiceAgentApiConfig(modelId: _testModelId);

VhrpRealtimeAdapter _makeAdapter(
  FakeVhrpTransport fake, {
  String? token = _testToken,
}) {
  return VhrpRealtimeAdapter(
    transport: fake,
    tokenProvider: () async => token,
    urlResolver: (_) =>
        Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
  );
}

/// Decodes the nth sent frame (0-indexed) as a Dart map.
Map<String, Object?> _decodeSent(FakeVhrpTransport fake, int index) {
  expect(fake.sentBytes.length, greaterThan(index),
      reason: 'Expected at least ${index + 1} sent frames');
  final decoded = cbor.decode(fake.sentBytes[index]);
  expect(decoded, isA<CborMap>());
  return _cborMapToMap(decoded as CborMap);
}

Map<String, Object?> _cborMapToMap(CborMap map) {
  final result = <String, Object?>{};
  for (final entry in map.entries) {
    if (entry.key is CborString) {
      result[(entry.key as CborString).toString()] =
          _cborToValue(entry.value);
    }
  }
  return result;
}

Object? _cborToValue(CborValue? v) {
  return switch (v) {
    null => null,
    CborNull() => null,
    CborBool b => b.value,
    CborInt i => i.toInt(),
    CborFloat f => f.value,
    CborString s => s.toString(),
    CborBytes b => Uint8List.fromList(b.bytes),
    CborMap m => _cborMapToMap(m),
    CborList l => [for (final e in l) _cborToValue(e)],
    _ => null,
  };
}

/// Injects a `session.ready` S2C frame.
void _injectSessionReady(
  FakeVhrpTransport fake, {
  String sessionId = 'srv-session-001',
  String threadId = 'srv-thread-001',
  String? conversationId = 'srv-conv-001',
}) {
  final frame = CborMap({
    CborString('type'): CborString('session.ready'),
    CborString('replyTo'): CborString(''),
    CborString('body'): CborMap({
      CborString('sessionId'): CborString(sessionId),
      CborString('threadId'): CborString(threadId),
      if (conversationId != null)
        CborString('conversationId'): CborString(conversationId),
      CborString('capabilities'): CborMap({
        CborString('extensions'): CborList([]),
      }),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(frame)));
}

/// Injects a `session.resumed` S2C frame.
void _injectSessionResumed(
  FakeVhrpTransport fake, {
  String sessionId = 'srv-session-resumed-001',
  String threadId = 'srv-thread-001',
  String? conversationId = 'srv-conv-001',
}) {
  final frame = CborMap({
    CborString('type'): CborString('session.resumed'),
    CborString('replyTo'): CborString(''),
    CborString('body'): CborMap({
      CborString('sessionId'): CborString(sessionId),
      CborString('threadId'): CborString(threadId),
      if (conversationId != null)
        CborString('conversationId'): CborString(conversationId),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(frame)));
}

/// Injects an `error` S2C frame.
void _injectError(
  FakeVhrpTransport fake,
  String code, {
  bool recoverable = true,
  String? replyTo,
}) {
  final bodyMap = CborMap({
    CborString('code'): CborString(code),
    CborString('message'): CborString('$code error'),
    CborString('recoverable'): CborBool(recoverable),
  });
  final frame = CborMap({
    CborString('type'): CborString('error'),
    if (replyTo != null) CborString('replyTo'): CborString(replyTo),
    CborString('body'): bodyMap,
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(frame)));
}

/// Injects a `thread.snapshot` S2C frame with zero items.
void _injectThreadSnapshot(FakeVhrpTransport fake) {
  final frame = CborMap({
    CborString('type'): CborString('thread.snapshot'),
    CborString('body'): CborMap({
      CborString('threadId'): CborString('srv-thread-001'),
      CborString('conversationId'): CborString('srv-conv-001'),
      CborString('items'): CborList([]),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(frame)));
}

/// Injects a `thread.patch` with an `add_item` op.
void _injectPatchAddItem(FakeVhrpTransport fake, String itemId,
    {String type = 'function_call', String status = 'in_progress'}) {
  final frame = CborMap({
    CborString('type'): CborString('thread.patch'),
    CborString('body'): CborMap({
      CborString('ops'): CborList([
        CborMap({
          CborString('op'): CborString('add_item'),
          CborString('item'): CborMap({
            CborString('id'): CborString(itemId),
            CborString('type'): CborString(type),
            CborString('role'): CborString('assistant'),
            CborString('status'): CborString(status),
            CborString('content'): CborList([]),
          }),
        }),
      ]),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(frame)));
}

/// Helper: connect adapter, inject session.ready, return after connected.
Future<void> _connectAndReady(
  VhrpRealtimeAdapter adapter,
  FakeVhrpTransport fake,
) async {
  final connectFuture = adapter.connect(_testConfig);
  // Give the async connect chain a tick to send session.open.
  await Future<void>.delayed(Duration.zero);
  _injectSessionReady(fake);
  await connectFuture;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('interrupt()', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async => adapter.dispose());

    test(
      // Use-case / contract:
      //   When the user "barges in" while the assistant is speaking, the app
      //   calls interrupt() and the assistant stops.  VHRP §4.11 requires
      //   `assistant.interrupt` with `reason:"barge_in"` (one-way, no messageId).
      'sends assistant.interrupt with reason:barge_in when connected',
      () async {
        await _connectAndReady(adapter, fake);

        // Clear the session.open frame so index 0 is the interrupt.
        final beforeCount = fake.sentBytes.length;

        await adapter.interrupt();

        expect(fake.sentBytes.length, beforeCount + 1,
            reason: 'One frame should have been sent');

        final frame = _decodeSent(fake, beforeCount);
        expect(frame['type'], 'assistant.interrupt');
        expect(frame.containsKey('messageId'), isFalse,
            reason: 'One-way message must not carry messageId');
        final body = frame['body'] as Map<String, Object?>;
        expect(body['reason'], 'barge_in');
      },
    );

    test(
      // Use-case / contract:
      //   When not connected, interrupt() is a no-op.  No wire frame sent.
      //   The user should not observe a crash.
      'is a no-op when not connected',
      () async {
        // Do NOT connect.
        final before = fake.sentBytes.length;
        await adapter.interrupt(); // should not throw
        expect(fake.sentBytes.length, before);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────

  group('cancelFunctionCalls()', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async => adapter.dispose());

    test(
      // Use-case / contract:
      //   If the model requests function calls that the app decides to cancel
      //   (e.g. because the user interrupted), calling cancelFunctionCalls()
      //   marks those items as incomplete in the local thread immediately.
      //   VHRP/1 has no wire cancel message — this is local-only (OAI parity).
      'marks matching functionCall items as incomplete in local thread',
      () async {
        await _connectAndReady(adapter, fake);

        // Inject a functionCall item via thread.patch.
        const itemId = 'item-fc-001';
        _injectPatchAddItem(fake, itemId, type: 'function_call');
        await Future<void>.delayed(Duration.zero);

        // Confirm item is in_progress before cancel.
        final before = adapter.thread.findItem(itemId);
        expect(before, isNotNull);
        expect(before!.status, RealtimeThreadItemStatus.inProgress);

        // Cancel by itemId.
        adapter.cancelFunctionCalls(itemIds: {itemId});

        final after = adapter.thread.findItem(itemId);
        expect(after!.status, RealtimeThreadItemStatus.incomplete,
            reason:
                'functionCall item should be marked incomplete after cancel');
      },
    );

    test(
      // Use-case / contract:
      //   cancelFunctionCalls() must not send any wire message — VHRP/1 has no
      //   cancel C2S type.  Sending an unexpected frame would be a protocol error.
      'does not send any wire message (no VHRP cancel C2S exists)',
      () async {
        await _connectAndReady(adapter, fake);
        final beforeCount = fake.sentBytes.length;

        adapter.cancelFunctionCalls(itemIds: {'any-id'});

        expect(fake.sentBytes.length, beforeCount,
            reason: 'cancelFunctionCalls must not send any wire frame');
      },
    );

    test(
      // Use-case / contract:
      //   Cancelled items re-stay incomplete after a snapshot replaces the
      //   thread (e.g. after reconnect).  The local cancel set is preserved.
      'keeps items incomplete after snapshot replaces thread',
      () async {
        await _connectAndReady(adapter, fake);

        const itemId = 'item-fc-snap-001';
        _injectPatchAddItem(fake, itemId, type: 'function_call');
        await Future<void>.delayed(Duration.zero);

        adapter.cancelFunctionCalls(itemIds: {itemId});

        // Inject a snapshot that brings the item back as in_progress.
        final snapshotFrame = CborMap({
          CborString('type'): CborString('thread.snapshot'),
          CborString('body'): CborMap({
            CborString('threadId'): CborString('srv-thread-001'),
            CborString('conversationId'): CborString('srv-conv-001'),
            CborString('items'): CborList([
              CborMap({
                CborString('id'): CborString(itemId),
                CborString('type'): CborString('function_call'),
                CborString('role'): CborString('assistant'),
                CborString('status'): CborString('in_progress'),
                CborString('content'): CborList([]),
              }),
            ]),
          }),
        });
        fake.injectInbound(
            Uint8List.fromList(cbor.encode(snapshotFrame)));
        await Future<void>.delayed(Duration.zero);

        // Item should still be incomplete thanks to re-application.
        final item = adapter.thread.findItem(itemId);
        expect(item, isNotNull);
        expect(item!.status, RealtimeThreadItemStatus.incomplete,
            reason:
                'Locally cancelled item must remain incomplete after snapshot');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────

  group('resume reconnect — success scenario', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async => adapter.dispose());

    test(
      // Use-case / contract:
      //   Mobile networks are unreliable.  After a transient disconnect the
      //   adapter must automatically reconnect and restore the session so the
      //   user can continue the conversation without any app restart.
      //   §6.1 step 2: session.open must carry resume.sessionId on reconnect.
      'sends session.open with resume.sessionId after simulateServerDisconnect',
      () async {
        await _connectAndReady(adapter, fake);
        final sessionIdBefore = 'srv-session-001'; // matches _injectSessionReady

        final sentCountAfterConnect = fake.sentBytes.length;

        // Trigger unexpected disconnect.
        fake.simulateServerDisconnect();
        // Give the reconnect loop a tick to start (delay=500ms on first attempt
        // but we need the loop to at least reach the connect() call).
        // We shorten the wait by having the transport connect immediately.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // At this point the loop should have called transport.connect() again.
        // The fake transport is now "connected" again.  We need to inject
        // session.resumed.
        _injectSessionResumed(fake,
            sessionId: 'srv-session-resumed-001',
            threadId: 'srv-thread-001');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Find the reconnect session.open (last batch of sent bytes after
        // initial connect).
        final reconnectFrames =
            fake.sentBytes.sublist(sentCountAfterConnect);
        expect(reconnectFrames, isNotEmpty,
            reason: 'Reconnect loop must have sent a session.open');

        // The first reconnect frame should be session.open with resume.
        final reconnectOpen = _cborMapToMap(
            cbor.decode(reconnectFrames.first) as CborMap);
        expect(reconnectOpen['type'], 'session.open',
            reason: 'First reconnect frame must be session.open');
        final body =
            reconnectOpen['body'] as Map<String, Object?>? ?? {};
        final resume = body['resume'] as Map<String, Object?>?;
        expect(resume, isNotNull,
            reason:
                'session.open on reconnect must contain resume field (§6.1 step 2)');
        expect(resume!['sessionId'], sessionIdBefore,
            reason:
                'resume.sessionId must equal the last known session ID');
      },
    );

    test(
      // Use-case / contract:
      //   After reconnect and session.resumed, the adapter must request a
      //   full thread snapshot (§6.1 step 4) so the local thread is brought
      //   up to date with any changes that happened during the disconnect.
      'sends thread.sync.request after session.resumed',
      () async {
        await _connectAndReady(adapter, fake);
        final sentCountAfterConnect = fake.sentBytes.length;

        fake.simulateServerDisconnect();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        _injectSessionResumed(fake);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Look for thread.sync.request in the frames sent after initial connect.
        final laterFrames = fake.sentBytes.sublist(sentCountAfterConnect);
        final types = laterFrames.map((b) {
          final m = cbor.decode(b) as CborMap;
          return _cborMapToMap(m)['type'];
        }).toList();

        expect(types, contains('thread.sync.request'),
            reason:
                'Adapter must send thread.sync.request after session.resumed (§6.1 step 4)');
      },
    );

    test(
      // Use-case / contract:
      //   After the server responds with a thread.snapshot following reconnect,
      //   the local thread is fully replaced (§5.4) and the adapter reports
      //   `connected` so the UI can resume normal operation.
      'transitions to connected and replaces thread after snapshot',
      () async {
        await _connectAndReady(adapter, fake);

        fake.simulateServerDisconnect();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        _injectSessionResumed(fake);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Inject the thread snapshot.
        _injectThreadSnapshot(fake);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          adapter.connectionState.phase,
          RealtimeAdapterConnectionPhase.connected,
          reason: 'Adapter must be connected after successful resume + snapshot',
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────

  group('resume reconnect — failure (resume.not_available) fallback', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async => adapter.dispose());

    test(
      // Use-case / contract:
      //   If the server no longer holds the session (e.g. it restarted),
      //   error(resume.not_available) is returned.  The adapter must fall back
      //   to a fresh session.open WITHOUT the resume field (§6.1 fallback).
      'sends fresh session.open without resume on resume.not_available',
      () async {
        await _connectAndReady(adapter, fake);
        final sentCountAfterConnect = fake.sentBytes.length;

        fake.simulateServerDisconnect();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // First reconnect attempt: inject resume.not_available error.
        // Find the messageId of the resume session.open to target the replyTo.
        final reconnectFrames =
            fake.sentBytes.sublist(sentCountAfterConnect);
        expect(reconnectFrames, isNotEmpty);
        final resumeOpen =
            _cborMapToMap(cbor.decode(reconnectFrames.first) as CborMap);
        final resumeOpenMsgId = resumeOpen['messageId'] as String?;

        _injectError(fake, 'resume.not_available',
            recoverable: true,
            replyTo: resumeOpenMsgId);
        // Give the reconnect loop time to:
        //   1. Catch the RealtimeAdapterError(resume.not_available).
        //   2. Fall through to the fresh session.open branch.
        //   3. Send the fresh session.open on the still-open connection.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        // After resume.not_available, a fresh session.open should be sent
        // without a `resume` field.
        final allLater = fake.sentBytes.sublist(sentCountAfterConnect);
        final freshOpens = <Map<String, Object?>>[];
        for (final b in allLater) {
          final m = _cborMapToMap(cbor.decode(b) as CborMap);
          if (m['type'] == 'session.open') {
            final body = m['body'] as Map<String, Object?>? ?? {};
            if (!body.containsKey('resume')) {
              freshOpens.add(m);
            }
          }
        }

        expect(freshOpens, isNotEmpty,
            reason:
                'Adapter must send a fresh session.open without resume after '
                'error(resume.not_available) (§6.1 fallback)');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────

  group('desync → recovery integration', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async => adapter.dispose());

    test(
      // Use-case / contract:
      //   If a thread.patch op cannot be applied (e.g. unknown itemId),
      //   the adapter detects desync and sends thread.sync.request.  When the
      //   server responds with thread.snapshot the local thread is fully
      //   replaced.  This uses the same single recovery path as reconnect (§6).
      'desync triggers thread.sync.request and snapshot replaces thread',
      () async {
        await _connectAndReady(adapter, fake);

        // Inject a patch with an op on a non-existent item → desync.
        final badPatch = CborMap({
          CborString('type'): CborString('thread.patch'),
          CborString('body'): CborMap({
            CborString('ops'): CborList([
              CborMap({
                CborString('op'): CborString('set_status'),
                CborString('itemId'): CborString('non-existent-item-xyz'),
                CborString('status'): CborString('completed'),
              }),
            ]),
          }),
        });
        fake.injectInbound(Uint8List.fromList(cbor.encode(badPatch)));
        await Future<void>.delayed(Duration.zero);

        // Adapter should have sent thread.sync.request.
        final types = fake.sentBytes.map((b) {
          final m = cbor.decode(b) as CborMap;
          return _cborMapToMap(m)['type'];
        }).toList();
        expect(types, contains('thread.sync.request'),
            reason:
                'Desync must trigger thread.sync.request (§5.5 / §6 single recovery path)');

        // Inject the snapshot in response.
        _injectThreadSnapshot(fake);
        await Future<void>.delayed(Duration.zero);

        // Thread should now be the snapshot (empty items).
        expect(adapter.thread.items, isEmpty,
            reason: 'Snapshot must replace the local thread wholesale (§5.4)');
      },
    );

    test(
      // Use-case / contract:
      //   Both desync (patch_apply_failed) and resume reconnect resolve
      //   through the same code path: thread.sync.request → thread.snapshot
      //   → _projector.applySnapshot.  There is no secondary recovery path.
      //   This is the "single recovery path" guarantee of VHRP §6.
      'snapshot received after sync.request replaces thread (unified path)',
      () async {
        await _connectAndReady(adapter, fake);

        // First add an item to the thread.
        _injectPatchAddItem(fake, 'item-to-be-replaced', type: 'message');
        await Future<void>.delayed(Duration.zero);
        expect(adapter.thread.findItem('item-to-be-replaced'), isNotNull);

        // Simulate a desync and the subsequent snapshot that has different items.
        _injectThreadSnapshot(fake); // snapshot has zero items
        await Future<void>.delayed(Duration.zero);

        expect(
          adapter.thread.findItem('item-to-be-replaced'),
          isNull,
          reason:
              'applySnapshot replaces the thread wholesale — old items must be gone',
        );
      },
    );
  });
}
