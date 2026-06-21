// Tests for VhrpRealtimeAdapter — Step 5: user content send methods.
//
// Contract assertions (handoff doc §9.3):
//
//   S1 sendText: returns a non-empty local itemId; the thread gains one user
//      message item with an inProgress status and a text part, and
//      threadUpdates fires.
//
//   S2 sendText wire: sentBytes[1] (after session.open at [0]) decodes to a
//      CBOR map with type=turn.text.submit, body.clientItemId == returned
//      itemId, body.text == input text, and body.messageId non-empty.
//
//   S3 sendText + idempotent merge: after sendText, injecting server ops
//      add_item / append_text / set_status(completed) for the same
//      clientItemId must produce exactly one item in the thread — not two.
//
//   S4 sendAudioOneShot wire: body.pcm is CBOR bstr (Uint8List after decode),
//      NOT a base64 string.  sampleRate=24000, channels=1, bitDepth=16.
//
//   S5 sendImage wire: body.imageBytes is CBOR bstr (Uint8List after decode),
//      NOT a base64 string.
//
//   S6 sendFunctionOutput: local thread gets a functionCallOutput item with the
//      correct callId/output/disposition/errorMessage.  sentBytes decodes to
//      tool.result.submit with correct fields.
//
//   S7 sendText while not connected: throws StateError (not silently dropped).

import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

const String _testToken = 'test-jwt-token-xyz';
const String _testModelId = 'vagina-v1-turbo';

final _testConfig = HostedVoiceAgentApiConfig(modelId: _testModelId);

VhrpRealtimeAdapter _makeAdapter(FakeVhrpTransport fake) {
  return VhrpRealtimeAdapter(
    transport: fake,
    tokenProvider: () async => _testToken,
    urlResolver: (_) =>
        Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
  );
}

/// Connects the adapter and awaits session.ready so the adapter is fully
/// connected before tests call send* methods.
Future<void> _connect(VhrpRealtimeAdapter adapter, FakeVhrpTransport fake) async {
  final connectFuture = adapter.connect(_testConfig);
  await Future<void>.delayed(Duration.zero);
  _injectSessionReady(fake);
  await connectFuture;
}

void _injectSessionReady(FakeVhrpTransport fake) {
  final map = CborMap({
    CborString('type'): CborString('session.ready'),
    CborString('replyTo'): CborString('session-open-1'),
    CborString('body'): CborMap({
      CborString('sessionId'): CborString('srv-session-001'),
      CborString('threadId'): CborString('srv-thread-001'),
      CborString('capabilities'): CborMap({
        CborString('extensions'): CborList([]),
      }),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects a `thread.patch` with [ops] into [fake].
void _injectPatch(FakeVhrpTransport fake, List<Map<String, Object?>> ops) {
  final cborOps = CborList(ops.map((op) {
    final m = CborMap({});
    op.forEach((k, v) {
      m[CborString(k)] = _dartToCbor(v);
    });
    return m;
  }).toList());

  final map = CborMap({
    CborString('type'): CborString('thread.patch'),
    CborString('body'): CborMap({
      CborString('ops'): cborOps,
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

CborValue _dartToCbor(Object? value) {
  return switch (value) {
    null => const CborNull(),
    bool v => CborBool(v),
    int v => CborSmallInt(v),
    double v => CborFloat(v),
    String v => CborString(v),
    Uint8List v => CborBytes(v),
    Map<String, Object?> v => CborMap({
        for (final e in v.entries)
          CborString(e.key): _dartToCbor(e.value),
      }),
    List<Object?> v => CborList(v.map(_dartToCbor).toList()),
    _ => CborString(value.toString()),
  };
}

/// Decodes a CBOR binary frame into a Dart Map.
Map<String, Object?> _decodeCborFrame(Uint8List bytes) {
  final decoded = cbor.decode(bytes);
  expect(decoded, isA<CborMap>(), reason: 'Frame must be a CBOR map');
  return _cborMapToDart(decoded as CborMap);
}

Map<String, Object?> _cborMapToDart(CborMap map) {
  return {
    for (final e in map.entries)
      if (e.key is CborString) (e.key as CborString).toString(): _cborToDart(e.value),
  };
}

Object? _cborToDart(CborValue? v) {
  return switch (v) {
    null => null,
    CborNull() => null,
    CborBool b => b.value,
    CborInt i => i.toInt(),
    CborFloat f => f.value,
    CborString s => s.toString(),
    CborBytes b => Uint8List.fromList(b.bytes),
    CborMap m => _cborMapToDart(m),
    CborList l => [for (final e in l) _cborToDart(e)],
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late FakeVhrpTransport fake;
  late VhrpRealtimeAdapter adapter;

  setUp(() {
    fake = FakeVhrpTransport();
    adapter = _makeAdapter(fake);
  });

  tearDown(() async {
    await adapter.dispose();
    await fake.dispose();
  });

  // ── S1: sendText local thread + threadUpdates ────────────────────────────────

  group('S1 — sendText local thread', () {
    test(
      'sendText returns a non-empty itemId and adds a user message item '
      'with inProgress status; threadUpdates fires exactly once',
      () async {
        // Contract S1: callers receive a local handle for the optimistically
        // added item before the server echoes it back.
        await _connect(adapter, fake);

        final threadEvents = <RealtimeThread>[];
        final sub = adapter.threadUpdates.listen(threadEvents.add);

        final itemId = await adapter.sendText('こんにちは');

        // (a) itemId must be non-empty ASCII, ≤ 64 chars.
        expect(itemId, isNotEmpty, reason: 'S1a: itemId must be non-empty');
        expect(itemId.length, lessThanOrEqualTo(64),
            reason: 'S1a: itemId must be ≤ 64 chars');
        expect(
          RegExp(r'^[\x20-\x7E]+$').hasMatch(itemId),
          isTrue,
          reason: 'S1a: itemId must be ASCII',
        );

        // (b) thread gains exactly one new user message item.
        final item = adapter.thread.findItem(itemId);
        expect(item, isNotNull, reason: 'S1b: item must be in thread');
        expect(item!.type, equals(RealtimeThreadItemType.message),
            reason: 'S1b: item type = message');
        expect(item.role, equals(RealtimeThreadItemRole.user),
            reason: 'S1b: item role = user');
        expect(item.status, equals(RealtimeThreadItemStatus.inProgress),
            reason: 'S1b: initial status = inProgress');
        expect(item.content, isNotEmpty,
            reason: 'S1b: placeholder content part must be present');
        expect(item.content.first, isA<RealtimeThreadTextPart>(),
            reason: 'S1b: content[0] must be a text part');

        // (c) threadUpdates fired.
        expect(threadEvents, isNotEmpty, reason: 'S1c: threadUpdates must fire');

        await sub.cancel();
      },
    );
  });

  // ── S2: sendText wire contract ───────────────────────────────────────────────

  group('S2 — sendText wire contract', () {
    test(
      'sendText emits a CBOR turn.text.submit frame with clientItemId, '
      'text, and messageId',
      () async {
        // Contract S2: the frame at sentBytes[1] (session.open is at [0])
        // must match the wire spec for turn.text.submit.
        await _connect(adapter, fake);

        final itemId = await adapter.sendText('Hello VHRP');

        // sentBytes[0] = session.open (from connect), [1] = turn.text.submit.
        expect(fake.sentBytes.length, greaterThanOrEqualTo(2),
            reason: 'S2: at least 2 frames must have been sent');

        final env = _decodeCborFrame(fake.sentBytes[1]);
        expect(env['type'], equals('turn.text.submit'),
            reason: 'S2: type mismatch');

        // messageId is at the root envelope level (not inside body) per codec.
        expect(env['messageId'], isNotNull,
            reason: 'S2: messageId must be present at root');
        expect((env['messageId'] as String).isNotEmpty, isTrue,
            reason: 'S2: messageId must be non-empty');

        final body = env['body'] as Map<String, Object?>;
        expect(body['clientItemId'], equals(itemId),
            reason: 'S2: clientItemId must equal returned itemId');
        expect(body['text'], equals('Hello VHRP'),
            reason: 'S2: text must match input');
      },
    );
  });

  // ── S3: sendText idempotent merge with server ops ────────────────────────────

  group('S3 — sendText idempotent merge', () {
    test(
      'after sendText, server add_item+append_text+set_status for the same '
      'clientItemId must produce exactly ONE item (no duplicate)',
      () async {
        // Contract S3: the pre-numbered client item and the server-canonical
        // item must unify into a single thread entry (§5.5, §8 idempotency).
        await _connect(adapter, fake);

        final itemId = await adapter.sendText('merge test');

        // Before server ops: 1 item (the optimistic one).
        expect(adapter.thread.items.length, equals(1),
            reason: 'S3: must start with 1 optimistic item');

        // Server sends add_item (same id) + append_text delta + set_status.
        _injectPatch(fake, [
          {
            'op': 'add_item',
            'item': {
              'id': itemId,
              'type': 'message',
              'role': 'user',
              'status': 'in_progress',
              'content': <Object?>[],
            },
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        _injectPatch(fake, [
          {
            'op': 'append_text',
            'itemId': itemId,
            'contentIndex': 0,
            'delta': 'merge test',
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        _injectPatch(fake, [
          {
            'op': 'set_status',
            'itemId': itemId,
            'status': 'completed',
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        // Still exactly ONE item.
        expect(adapter.thread.items.length, equals(1),
            reason: 'S3: must still have exactly 1 item after server ops');

        final merged = adapter.thread.findItem(itemId)!;
        expect(merged.status, equals(RealtimeThreadItemStatus.completed),
            reason: 'S3: item status must be completed after set_status');

        // Text part must have the appended delta.
        expect(merged.content, isNotEmpty);
        final textPart = merged.content.first as RealtimeThreadTextPart;
        expect(textPart.text, equals('merge test'),
            reason: 'S3: text part must contain the server-appended delta');
      },
    );
  });

  // ── S4: sendAudioOneShot — pcm is raw bytes, NOT base64 ─────────────────────

  group('S4 — sendAudioOneShot wire contract (raw bytes)', () {
    test(
      'sendAudioOneShot encodes pcm as CBOR bstr (raw bytes), '
      'not as a base64 string; sampleRate=24000, channels=1, bitDepth=16',
      () async {
        // Contract S4: CBOR bstr guarantees the receiver can decode PCM without
        // a base64 round-trip.  A CborString would violate the wire contract.
        await _connect(adapter, fake);

        final pcm = Uint8List.fromList(List.generate(64, (i) => i));
        await adapter.sendAudioOneShot(pcm);

        // sentBytes[0]=session.open, [1]=turn.audio.submit.
        expect(fake.sentBytes.length, greaterThanOrEqualTo(2));

        final env = _decodeCborFrame(fake.sentBytes[1]);
        expect(env['type'], equals('turn.audio.submit'), reason: 'S4: type');

        final body = env['body'] as Map<String, Object?>;

        // pcm must arrive as Uint8List (CborBytes decoded), NOT a String.
        final pcmValue = body['pcm'];
        expect(pcmValue, isA<Uint8List>(),
            reason: 'S4: pcm must be CBOR bstr (raw bytes), not base64 string');
        expect(pcmValue as Uint8List, equals(pcm),
            reason: 'S4: pcm bytes must be identical to input');

        expect(body['sampleRate'], equals(24000), reason: 'S4: sampleRate');
        expect(body['channels'], equals(1), reason: 'S4: channels');
        expect(body['bitDepth'], equals(16), reason: 'S4: bitDepth');
      },
    );
  });

  // ── S5: sendImage — imageBytes is raw bytes, NOT base64 ─────────────────────

  group('S5 — sendImage wire contract (raw bytes)', () {
    test(
      'sendImage encodes imageBytes as CBOR bstr (raw bytes), '
      'not as a base64 string',
      () async {
        // Contract S5: MIME detection is server-side; the client must send raw
        // bytes so the server receives the original binary data.
        await _connect(adapter, fake);

        // Minimal fake PNG header.
        final png = Uint8List.fromList(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        );
        await adapter.sendImage(png);

        expect(fake.sentBytes.length, greaterThanOrEqualTo(2));

        final env = _decodeCborFrame(fake.sentBytes[1]);
        expect(env['type'], equals('turn.image.submit'), reason: 'S5: type');

        final body = env['body'] as Map<String, Object?>;

        final imgValue = body['imageBytes'];
        expect(imgValue, isA<Uint8List>(),
            reason: 'S5: imageBytes must be CBOR bstr (raw bytes), '
                'not a base64 string');
        expect(imgValue as Uint8List, equals(png),
            reason: 'S5: imageBytes must be identical to input');
      },
    );
  });

  // ── S6: sendFunctionOutput ───────────────────────────────────────────────────

  group('S6 — sendFunctionOutput', () {
    test(
      'sendFunctionOutput adds a functionCallOutput item locally and sends '
      'tool.result.submit with correct fields',
      () async {
        // Contract S6: tool result is immediately visible in the thread and
        // the server receives a wire frame with all correlation fields.
        await _connect(adapter, fake);

        final threadEvents = <RealtimeThread>[];
        final sub = adapter.threadUpdates.listen(threadEvents.add);

        final itemId = await adapter.sendFunctionOutput(
          callId: 'call_01',
          output: '{"ok":true}',
          disposition: RealtimeToolOutputDisposition.error,
          errorMessage: 'something went wrong',
        );

        // (a) Local item added.
        expect(itemId, isNotEmpty, reason: 'S6a: itemId must be non-empty');
        final item = adapter.thread.findItem(itemId);
        expect(item, isNotNull, reason: 'S6a: item must be in thread');
        expect(item!.type, equals(RealtimeThreadItemType.functionCallOutput),
            reason: 'S6a: type = functionCallOutput');
        expect(item.callId, equals('call_01'), reason: 'S6a: callId');
        expect(item.output, equals('{"ok":true}'), reason: 'S6a: output');
        expect(item.toolOutputDisposition,
            equals(RealtimeToolOutputDisposition.error),
            reason: 'S6a: disposition');
        expect(item.toolErrorMessage, equals('something went wrong'),
            reason: 'S6a: errorMessage');
        expect(item.status, equals(RealtimeThreadItemStatus.completed),
            reason: 'S6a: initial status = completed');

        // (b) threadUpdates fired.
        expect(threadEvents, isNotEmpty, reason: 'S6b: threadUpdates must fire');

        // (c) Wire frame.
        expect(fake.sentBytes.length, greaterThanOrEqualTo(2));
        final env = _decodeCborFrame(fake.sentBytes[1]);
        expect(env['type'], equals('tool.result.submit'), reason: 'S6c: type');

        // messageId is at root envelope level per codec.
        expect(env['messageId'], isNotNull, reason: 'S6c: messageId present at root');

        final body = env['body'] as Map<String, Object?>;
        expect(body['clientItemId'], equals(itemId),
            reason: 'S6c: clientItemId');
        expect(body['callId'], equals('call_01'), reason: 'S6c: callId');
        expect(body['output'], equals('{"ok":true}'), reason: 'S6c: output');
        expect(body['disposition'], equals('error'),
            reason: 'S6c: disposition wire value = "error"');
        expect(body['errorMessage'], equals('something went wrong'),
            reason: 'S6c: errorMessage');

        await sub.cancel();
      },
    );

    test(
      'sendFunctionOutput with disposition=success omits errorMessage from wire',
      () async {
        // Contract S6-success: when disposition=success and errorMessage is null,
        // errorMessage must be absent from the CBOR frame (not present as null).
        await _connect(adapter, fake);

        await adapter.sendFunctionOutput(
          callId: 'call_02',
          output: 'ok',
          // disposition defaults to success
        );

        final env = _decodeCborFrame(fake.sentBytes[1]);
        final body = env['body'] as Map<String, Object?>;
        expect(body['disposition'], equals('success'),
            reason: 'S6-success: disposition');
        expect(body.containsKey('errorMessage'), isFalse,
            reason: 'S6-success: errorMessage must be absent when null');
      },
    );
  });

  // ── S7: send* while not connected throws StateError ──────────────────────────

  group('S7 — send* while not connected', () {
    test(
      'sendText throws StateError before connect() is called',
      () async {
        // Contract S7: silently swallowing sends when disconnected would leave
        // callers believing a response is in-flight — throwing is the honest
        // contract matching the semantics "send AND generate a response".
        expect(
          () => adapter.sendText('should throw'),
          throwsA(isA<StateError>()),
          reason: 'S7: sendText must throw StateError when not connected',
        );
      },
    );

    test(
      'sendAudioOneShot throws StateError before connect()',
      () {
        expect(
          () => adapter.sendAudioOneShot(Uint8List(4)),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'sendImage throws StateError before connect()',
      () {
        expect(
          () => adapter.sendImage(Uint8List(4)),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'sendFunctionOutput throws StateError before connect()',
      () {
        expect(
          () => adapter.sendFunctionOutput(callId: 'c', output: '{}'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  // ── Additional: itemIds are unique across calls ──────────────────────────────

  group('ID uniqueness', () {
    test(
      'consecutive sendText calls produce distinct itemIds',
      () async {
        // Contract: every optimistic item must have a unique local ID so the
        // thread model never has duplicate entries.
        await _connect(adapter, fake);

        final ids = <String>{};
        for (var i = 0; i < 5; i++) {
          ids.add(await adapter.sendText('msg $i'));
        }
        expect(ids.length, equals(5), reason: 'All itemIds must be distinct');
      },
    );
  });
}
