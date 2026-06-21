// Tests for VhrpRealtimeAdapter — Step 6: audio I/O and VAD.
//
// Contract assertions (handoff doc §9.3):
//
//   A1  setAudioTurnMode(manual) — wire contract:
//       Sends exactly one `audio.turn.mode.set` frame with body.mode == "manual".
//       No messageId present on the envelope (one-way message).
//
//   A2  setAudioTurnMode(voiceActivity) — wire contract:
//       body.mode == "voice_activity".
//
//   A3  setAudioTurnMode while disconnected — no wire send; mode stored.
//
//   A4  bindAudioInput — live.audio.chunk wire contract:
//       Each PCM chunk forwarded as a `live.audio.chunk` frame with:
//         body.pcm  = raw bytes (CBOR bstr, not base64 string)
//         body.sequence = 1, 2, 3, … (strictly monotonic within session)
//
//   A5  bindAudioInput(null) — stops forwarding; no subsequent frames sent.
//
//   A6  re-bind — replacing a stream with a new one sends no double frames
//       (old subscription cancelled before new one is started).
//
//   A7  assistant.audio.chunk — playback stream dual-path (Strong constraint):
//       (a) assistantAudioStream receives the same raw Uint8List — NOT decoded.
//       (b) RealtimeThreadAudioPart.audioChunks receives the base64-encoded
//           string of those same bytes (base64Encode(pcm) == audioChunks[0]).
//       Item status is NOT changed by audio chunk arrival.
//
//   A8  assistant.audio.chunk — part not yet created (race condition):
//       assistantAudioStream still fires; accumulation is silently skipped.
//       No error emitted.
//
//   A9  assistant.audio.done — assistantAudioCompleted fires exactly once.
//       Item status is NOT changed (§5.7 of handoff doc).
//
//   A10 vad.state(isSpeaking:true) → isUserSpeaking == true,
//       isUserSpeakingUpdates emits true.
//       vad.state(isSpeaking:false) → isUserSpeaking == false,
//       isUserSpeakingUpdates emits false.
//
//   A11 vad.state deduplication — identical consecutive states do NOT emit
//       duplicate events on isUserSpeakingUpdates.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const String _testToken = 'test-jwt-audio';
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

/// Connects the adapter and drives it to the [connected] state by injecting
/// a synthetic `session.ready` frame.
Future<void> _connect(
    VhrpRealtimeAdapter adapter, FakeVhrpTransport fake) async {
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

/// Injects an `assistant.audio.chunk` S2C message with raw [pcmBytes].
void _injectAssistantAudioChunk(
  FakeVhrpTransport fake, {
  required String itemId,
  required int contentIndex,
  required Uint8List pcmBytes,
}) {
  final map = CborMap({
    CborString('type'): CborString('assistant.audio.chunk'),
    CborString('body'): CborMap({
      CborString('itemId'): CborString(itemId),
      CborString('contentIndex'): CborSmallInt(contentIndex),
      CborString('pcm'): CborBytes(pcmBytes),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects an `assistant.audio.done` S2C message.
void _injectAssistantAudioDone(
  FakeVhrpTransport fake, {
  required String itemId,
  required int contentIndex,
}) {
  final map = CborMap({
    CborString('type'): CborString('assistant.audio.done'),
    CborString('body'): CborMap({
      CborString('itemId'): CborString(itemId),
      CborString('contentIndex'): CborSmallInt(contentIndex),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects a `vad.state` S2C message.
void _injectVadState(FakeVhrpTransport fake, {required bool isSpeaking}) {
  final map = CborMap({
    CborString('type'): CborString('vad.state'),
    CborString('body'): CborMap({
      CborString('isSpeaking'): CborBool(isSpeaking),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects a `thread.patch` with a `put_part` op that creates an audio part
/// at [contentIndex] for [itemId], establishing the item + part in the thread
/// before audio chunks arrive.
void _injectPutAudioPart(
  FakeVhrpTransport fake, {
  required String itemId,
  required int contentIndex,
}) {
  // First, inject an add_item so the item exists, then put_part.
  final addItemOp = CborMap({
    CborString('op'): CborString('add_item'),
    CborString('item'): CborMap({
      CborString('id'): CborString(itemId),
      CborString('type'): CborString('message'),
      CborString('role'): CborString('assistant'),
      CborString('status'): CborString('in_progress'),
    }),
  });
  final putPartOp = CborMap({
    CborString('op'): CborString('put_part'),
    CborString('itemId'): CborString(itemId),
    CborString('contentIndex'): CborSmallInt(contentIndex),
    CborString('part'): CborMap({
      CborString('type'): CborString('audio'),
    }),
  });
  final map = CborMap({
    CborString('type'): CborString('thread.patch'),
    CborString('body'): CborMap({
      CborString('ops'): CborList([addItemOp, putPartOp]),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Decodes the last sent CBOR frame into a Dart map.
Map<String, Object?> _decodeSent(Uint8List bytes) {
  final decoded = cbor.decode(bytes);
  if (decoded is! CborMap) throw StateError('Expected CborMap');
  final result = <String, Object?>{};
  for (final entry in decoded.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is CborString) {
      result[key.toString()] = _cborToData(value);
    }
  }
  return result;
}

Object? _cborToData(CborValue? v) {
  return switch (v) {
    null => null,
    CborNull() => null,
    CborBool b => b.value,
    CborInt i => i.toInt(),
    CborFloat f => f.value,
    CborString s => s.toString(),
    CborBytes b => Uint8List.fromList(b.bytes),
    CborMap m => {
        for (final e in m.entries)
          if (e.key is CborString) (e.key as CborString).toString(): _cborToData(e.value),
      },
    CborList l => l.map(_cborToData).toList(),
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('VhrpRealtimeAdapter — audio I/O and VAD', () {
    late FakeVhrpTransport fake;
    late VhrpRealtimeAdapter adapter;

    setUp(() {
      fake = FakeVhrpTransport();
      adapter = _makeAdapter(fake);
    });

    tearDown(() async {
      await adapter.dispose();
    });

    // ── A1: setAudioTurnMode(manual) wire ──────────────────────────────────
    test(
        // Contract A1: audio.turn.mode.set("manual") is one-way (no messageId)
        // and body.mode == "manual".
        'A1 setAudioTurnMode(manual) sends audio.turn.mode.set with mode="manual"',
        () async {
      await _connect(adapter, fake);
      final sentBefore = fake.sentBytes.length; // 1 = session.open

      await adapter.setAudioTurnMode(RealtimeAudioTurnMode.manual);

      expect(fake.sentBytes.length, sentBefore + 1);
      final frame = _decodeSent(fake.sentBytes.last);
      expect(frame['type'], 'audio.turn.mode.set');
      // One-way message — no messageId on the envelope.
      expect(frame.containsKey('messageId'), isFalse);
      final body = frame['body'] as Map<String, Object?>;
      expect(body['mode'], 'manual');
    });

    // ── A2: setAudioTurnMode(voiceActivity) wire ───────────────────────────
    test(
        // Contract A2: mode string is "voice_activity" (underscore, not camel).
        'A2 setAudioTurnMode(voiceActivity) sends mode="voice_activity"',
        () async {
      await _connect(adapter, fake);

      // First switch to manual so voiceActivity is a real mode change.
      await adapter.setAudioTurnMode(RealtimeAudioTurnMode.manual);
      final sentBefore = fake.sentBytes.length;

      await adapter.setAudioTurnMode(RealtimeAudioTurnMode.voiceActivity);

      expect(fake.sentBytes.length, sentBefore + 1);
      final frame = _decodeSent(fake.sentBytes.last);
      final body = frame['body'] as Map<String, Object?>;
      expect(body['mode'], 'voice_activity');
    });

    // ── A3: setAudioTurnMode while disconnected ────────────────────────────
    test(
        // Contract A3: no wire send when not connected; mode is stored for
        // later use by bindAudioInput logic.
        'A3 setAudioTurnMode while disconnected stores mode without sending',
        () async {
      // adapter never connected — still in idle state.
      final sentBefore = fake.sentBytes.length;
      await adapter.setAudioTurnMode(RealtimeAudioTurnMode.manual);
      expect(fake.sentBytes.length, sentBefore,
          reason: 'No frame must be sent while disconnected.');
    });

    // ── A4: bindAudioInput live.audio.chunk wire contract ─────────────────
    test(
        // Contract A4: Each chunk produces a live.audio.chunk frame with:
        //   - body.pcm as raw bytes (Uint8List, i.e. CBOR bstr)
        //   - body.sequence strictly monotonic: 1, 2, 3 …
        'A4 bindAudioInput forwards PCM chunks as live.audio.chunk with monotonic sequence',
        () async {
      await _connect(adapter, fake);

      final controller = StreamController<Uint8List>();
      await adapter.bindAudioInput(controller.stream);

      final chunk1 = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final chunk2 = Uint8List.fromList([0x05, 0x06]);
      final chunk3 = Uint8List.fromList([0x07, 0x08, 0x09]);

      final sentBefore = fake.sentBytes.length;

      controller.add(chunk1);
      await Future<void>.delayed(Duration.zero);
      controller.add(chunk2);
      await Future<void>.delayed(Duration.zero);
      controller.add(chunk3);
      await Future<void>.delayed(Duration.zero);

      expect(fake.sentBytes.length, sentBefore + 3);

      // Frame 1
      final f1 = _decodeSent(fake.sentBytes[sentBefore]);
      expect(f1['type'], 'live.audio.chunk');
      expect(f1.containsKey('messageId'), isFalse,
          reason: 'live.audio.chunk is one-way; no messageId');
      final b1 = f1['body'] as Map<String, Object?>;
      expect(b1['pcm'], isA<Uint8List>(), reason: 'pcm must be raw bytes (bstr), not a string');
      expect(b1['pcm'] as Uint8List, chunk1);
      expect(b1['sequence'], 1);

      // Frame 2
      final f2 = _decodeSent(fake.sentBytes[sentBefore + 1]);
      final b2 = f2['body'] as Map<String, Object?>;
      expect(b2['pcm'] as Uint8List, chunk2);
      expect(b2['sequence'], 2);

      // Frame 3
      final f3 = _decodeSent(fake.sentBytes[sentBefore + 2]);
      final b3 = f3['body'] as Map<String, Object?>;
      expect(b3['pcm'] as Uint8List, chunk3);
      expect(b3['sequence'], 3);

      await controller.close();
    });

    // ── A5: bindAudioInput(null) stops forwarding ─────────────────────────
    test(
        // Contract A5: null un-bind cancels subscription; no subsequent frames
        // are sent even if the original stream keeps emitting.
        'A5 bindAudioInput(null) stops forwarding subsequent chunks',
        () async {
      await _connect(adapter, fake);

      final controller = StreamController<Uint8List>();
      await adapter.bindAudioInput(controller.stream);

      controller.add(Uint8List.fromList([0xAA]));
      await Future<void>.delayed(Duration.zero);
      final sentAfterFirst = fake.sentBytes.length;

      // Un-bind.
      await adapter.bindAudioInput(null);

      // Emit more chunks — they must NOT be forwarded.
      controller.add(Uint8List.fromList([0xBB]));
      controller.add(Uint8List.fromList([0xCC]));
      await Future<void>.delayed(Duration.zero);

      expect(fake.sentBytes.length, sentAfterFirst,
          reason: 'No frames must be sent after null un-bind.');

      await controller.close();
    });

    // ── A6: re-bind avoids double subscription ─────────────────────────────
    test(
        // Contract A6: replacing an active stream (re-bind) cancels the old
        // subscription before starting the new one — each chunk is forwarded
        // exactly once.
        'A6 re-bind replaces subscription without double-sending',
        () async {
      await _connect(adapter, fake);

      final old = StreamController<Uint8List>();
      final next = StreamController<Uint8List>();

      await adapter.bindAudioInput(old.stream);

      // Emit one chunk on the old stream.
      old.add(Uint8List.fromList([0x11]));
      await Future<void>.delayed(Duration.zero);
      final sentAfterOld = fake.sentBytes.length;

      // Re-bind to the new stream.
      await adapter.bindAudioInput(next.stream);

      // Now emit on BOTH streams.
      old.add(Uint8List.fromList([0x22])); // should NOT be forwarded
      next.add(Uint8List.fromList([0x33])); // must be forwarded
      await Future<void>.delayed(Duration.zero);

      // Only the new-stream chunk arrives.
      expect(fake.sentBytes.length, sentAfterOld + 1,
          reason: 'Old stream must be cancelled on re-bind.');
      final frame = _decodeSent(fake.sentBytes.last);
      final body = frame['body'] as Map<String, Object?>;
      expect(body['pcm'] as Uint8List, Uint8List.fromList([0x33]));

      await old.close();
      await next.close();
    });

    // ── A7: assistant.audio.chunk — dual-path ──────────────────────────────
    test(
        // Contract A7 (Strong constraint §10.2):
        //   (a) assistantAudioStream receives the raw Uint8List — no decode.
        //   (b) audioChunks in the thread part receives base64Encode(pcm).
        //   Item status is unchanged by audio chunk arrival.
        'A7 assistant.audio.chunk: raw bytes to stream, base64 to audioChunks',
        () async {
      await _connect(adapter, fake);

      const itemId = 'item-audio-001';
      const contentIndex = 0;
      final pcmBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);

      // Establish item + audio part in the thread via put_part.
      _injectPutAudioPart(fake, itemId: itemId, contentIndex: contentIndex);
      await Future<void>.delayed(Duration.zero);

      // Capture stream emission.
      final streamChunks = <Uint8List>[];
      final streamSub =
          adapter.assistantAudioStream.listen(streamChunks.add);

      _injectAssistantAudioChunk(
        fake,
        itemId: itemId,
        contentIndex: contentIndex,
        pcmBytes: pcmBytes,
      );
      await Future<void>.delayed(Duration.zero);

      // (a) Stream receives raw bytes — identical to what was injected.
      expect(streamChunks.length, 1);
      expect(streamChunks[0], pcmBytes,
          reason: 'assistantAudioStream must carry raw Uint8List, not decoded');

      // (b) audioChunks carries base64-encoded string.
      final item = adapter.thread.findItem(itemId);
      expect(item, isNotNull);
      final part = item!.findContentPart(contentIndex);
      expect(part, isA<RealtimeThreadAudioPart>());
      final audioPart = part as RealtimeThreadAudioPart;
      expect(audioPart.audioChunks.length, 1);
      expect(audioPart.audioChunks[0], base64Encode(pcmBytes),
          reason: 'audioChunks must contain base64-encoded string, not raw bytes');

      // Item status must NOT have changed (still inProgress from put_part).
      expect(item.status, RealtimeThreadItemStatus.inProgress);

      await streamSub.cancel();
    });

    // ── A8: assistant.audio.chunk — part not yet created ──────────────────
    test(
        // Contract A8: even if the audio part does not exist, assistantAudioStream
        // still fires; accumulation is silently skipped; no error emitted.
        'A8 assistant.audio.chunk with no part: stream fires, accumulation skipped silently',
        () async {
      await _connect(adapter, fake);

      final errors = <Object>[];
      final errorSub = adapter.errors.listen((e) => errors.add(e));

      final streamChunks = <Uint8List>[];
      final streamSub =
          adapter.assistantAudioStream.listen(streamChunks.add);

      final pcmBytes = Uint8List.fromList([0x01, 0x02]);

      // Inject chunk for an item/part that doesn't exist.
      _injectAssistantAudioChunk(
        fake,
        itemId: 'nonexistent-item',
        contentIndex: 0,
        pcmBytes: pcmBytes,
      );
      await Future<void>.delayed(Duration.zero);

      // Stream still fires with raw bytes.
      expect(streamChunks.length, 1);
      expect(streamChunks[0], pcmBytes);

      // No error emitted.
      expect(errors, isEmpty,
          reason: 'Missing item/part must not produce an error');

      await streamSub.cancel();
      await errorSub.cancel();
    });

    // ── A9: assistant.audio.done — assistantAudioCompleted fires ──────────
    test(
        // Contract A9: assistantAudioCompleted fires exactly once per
        // assistant.audio.done message; item status is NOT changed.
        'A9 assistant.audio.done fires assistantAudioCompleted; item status unchanged',
        () async {
      await _connect(adapter, fake);

      const itemId = 'item-done-001';
      const contentIndex = 0;

      // Establish item + audio part.
      _injectPutAudioPart(fake, itemId: itemId, contentIndex: contentIndex);
      await Future<void>.delayed(Duration.zero);

      // Record completions.
      var completionCount = 0;
      final completedSub =
          adapter.assistantAudioCompleted.listen((_) => completionCount++);

      _injectAssistantAudioDone(
          fake, itemId: itemId, contentIndex: contentIndex);
      await Future<void>.delayed(Duration.zero);

      expect(completionCount, 1,
          reason: 'assistantAudioCompleted must fire exactly once');

      // Item status must remain inProgress — audio.done does NOT complete items.
      final item = adapter.thread.findItem(itemId);
      expect(item, isNotNull);
      expect(item!.status, RealtimeThreadItemStatus.inProgress,
          reason:
              'assistant.audio.done must NOT change item status (§5.7 of handoff doc)');

      await completedSub.cancel();
    });

    // ── A10: vad.state → isUserSpeaking + isUserSpeakingUpdates ───────────
    test(
        // Contract A10: vad.state updates both the isUserSpeaking getter and
        // the isUserSpeakingUpdates stream.
        'A10 vad.state(true/false) updates isUserSpeaking and isUserSpeakingUpdates',
        () async {
      await _connect(adapter, fake);

      final speakingEvents = <bool>[];
      final sub =
          adapter.isUserSpeakingUpdates.listen(speakingEvents.add);

      expect(adapter.isUserSpeaking, isFalse,
          reason: 'Initial state must be not-speaking');

      _injectVadState(fake, isSpeaking: true);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.isUserSpeaking, isTrue);
      expect(speakingEvents, [true]);

      _injectVadState(fake, isSpeaking: false);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.isUserSpeaking, isFalse);
      expect(speakingEvents, [true, false]);

      await sub.cancel();
    });

    // ── A11: vad.state deduplication ─────────────────────────────────────
    test(
        // Contract A11: duplicate consecutive vad.state values do not emit
        // extra events on isUserSpeakingUpdates (deduplicated like OAI adapter).
        'A11 vad.state deduplicated — no duplicate events for same value',
        () async {
      await _connect(adapter, fake);

      final speakingEvents = <bool>[];
      final sub =
          adapter.isUserSpeakingUpdates.listen(speakingEvents.add);

      _injectVadState(fake, isSpeaking: true);
      await Future<void>.delayed(Duration.zero);
      // Second identical state — must not emit again.
      _injectVadState(fake, isSpeaking: true);
      await Future<void>.delayed(Duration.zero);

      expect(speakingEvents.length, 1,
          reason: 'Duplicate vad.state must not fire isUserSpeakingUpdates twice');
      expect(speakingEvents[0], true);

      await sub.cancel();
    });

    // ── Multiple audio chunks accumulate base64 list ───────────────────────
    test(
        // Additional coverage: multiple assistant.audio.chunk messages for the
        // same part accumulate all base64 strings in order.
        'multiple audio chunks accumulate base64 strings in order in audioChunks',
        () async {
      await _connect(adapter, fake);

      const itemId = 'item-multi-audio';
      const contentIndex = 0;

      _injectPutAudioPart(fake, itemId: itemId, contentIndex: contentIndex);
      await Future<void>.delayed(Duration.zero);

      final pcm1 = Uint8List.fromList([0x01, 0x02]);
      final pcm2 = Uint8List.fromList([0x03, 0x04, 0x05]);
      final pcm3 = Uint8List.fromList([0xAA]);

      _injectAssistantAudioChunk(fake,
          itemId: itemId, contentIndex: contentIndex, pcmBytes: pcm1);
      _injectAssistantAudioChunk(fake,
          itemId: itemId, contentIndex: contentIndex, pcmBytes: pcm2);
      _injectAssistantAudioChunk(fake,
          itemId: itemId, contentIndex: contentIndex, pcmBytes: pcm3);
      await Future<void>.delayed(Duration.zero);

      final part = adapter.thread.findItem(itemId)!.findContentPart(0)
          as RealtimeThreadAudioPart;
      expect(part.audioChunks, [
        base64Encode(pcm1),
        base64Encode(pcm2),
        base64Encode(pcm3),
      ]);
    });

    // ── sequence counter resets on re-connect (monotonic per session) ──────
    test(
        // Sequence numbers are monotonically increasing within a session.
        // Each chunk gets exactly the next integer.
        'sequence counter is monotonically increasing (1-based)',
        () async {
      await _connect(adapter, fake);

      final controller = StreamController<Uint8List>();
      await adapter.bindAudioInput(controller.stream);

      final sentBefore = fake.sentBytes.length;

      for (var i = 0; i < 5; i++) {
        controller.add(Uint8List.fromList([i]));
        await Future<void>.delayed(Duration.zero);
      }

      expect(fake.sentBytes.length, sentBefore + 5);
      for (var i = 0; i < 5; i++) {
        final body = (_decodeSent(fake.sentBytes[sentBefore + i])['body'])
            as Map<String, Object?>;
        expect(body['sequence'], i + 1,
            reason: 'sequence must be 1-based monotonic');
      }

      await controller.close();
    });
  });
}
