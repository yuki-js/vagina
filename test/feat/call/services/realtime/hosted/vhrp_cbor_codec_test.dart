// Round-trip tests for the VHRP/1 CBOR codec.
//
// Testing philosophy (section 9.3 of the handoff doc):
//   Each test declares which user-facing contract it guards with a leading
//   contract comment.  The subject is the *user's experience*, not code paths.
//
// What these tests protect:
//   • A user's voice reaches the server as raw bytes — no base64 overhead
//     inflating the payload or wasting bandwidth.
//   • Images uploaded by a user arrive at the server as raw bytes, so the
//     backend can sniff the MIME type correctly.
//   • A user's text message round-trips without garbling Unicode.
//   • Tool results the user triggered reach the server intact.
//   • The app correctly reacts to each server message type, because decoding
//     produces the right typed value with the right field values.
//   • Unknown server message types fail decode instead of being silently
//     ignored as implicit stubs.
//   • The app does not crash on an unknown patch op; instead it surfaces the
//     raw op so the adapter can trigger sync-request recovery.

import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_cbor_codec.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

final _codec = VhrpCborCodec();

/// Convenience: encode a C2S message and decode the bytes back as a raw
/// CBOR map so tests can inspect the exact wire shape.
CborMap _encodeToCborMap(VhrpC2sMessage msg) {
  final bytes = _codec.encode(msg);
  return cbor.decode(bytes) as CborMap;
}

/// Convenience: build a minimal S2C CBOR frame for [type] with [bodyEntries]
/// and decode it.
VhrpS2cMessage _decodeS2c(
  String type,
  Map<String, CborValue> bodyEntries, {
  String? replyTo,
}) {
  final root = CborMap({
    CborString('type'): CborString(type),
    if (replyTo != null) CborString('replyTo'): CborString(replyTo),
    CborString('body'): CborMap({
      for (final e in bodyEntries.entries) CborString(e.key): e.value,
    }),
  });
  return _codec.decode(Uint8List.fromList(cbor.encode(root)));
}

/// Helper: reads a field from a [CborMap] as a String.
String? _textOf(CborMap map, String key) {
  final v = map[CborString(key)];
  return v is CborString ? v.toString() : null;
}

/// Helper: reads a body map from an outer CBOR envelope map.
CborMap _bodyOf(CborMap outer) => outer[CborString('body')] as CborMap;

// ─────────────────────────────────────────────────────────────────────────────
// C2S encode — text messages
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('VhrpCborCodec — C2S encode', () {
    test(
      // Contract: a user's text turn arrives at the server with the exact
      // text they typed, including multi-byte Unicode characters; nothing is
      // garbled in the encoding.
      'turn.text.submit encodes type, messageId, clientItemId, text',
      () {
        final msg = TurnTextSubmitMsg(
          messageId: 'msg-001',
          clientItemId: 'item-001',
          text: 'こんにちは世界',
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'turn.text.submit');
        expect(_textOf(root, 'messageId'), 'msg-001');
        expect(_textOf(body, 'clientItemId'), 'item-001');
        expect(_textOf(body, 'text'), 'こんにちは世界');
      },
    );

    test(
      // Contract: the audio bytes a user records travel to the server as raw
      // CBOR bstr — not as base64 text.  Any base64 inflation would waste
      // ~33% bandwidth on every voice chunk and degrade the real-time
      // experience.
      'live.audio.chunk encodes pcm as CBOR bstr (no base64)',
      () {
        final pcm = Uint8List.fromList([0x00, 0x01, 0x80, 0xFF, 0x7F]);
        final msg = LiveAudioChunkMsg(pcm: pcm, sequence: 42);
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'live.audio.chunk');
        // pcm field MUST be CBOR byte string, not a text string
        final pcmField = body[CborString('pcm')];
        expect(
          pcmField,
          isA<CborBytes>(),
          reason: 'pcm must be CBOR bstr (major type 2), not tstr',
        );
        // byte content must round-trip exactly
        expect((pcmField as CborBytes).bytes, equals(pcm));
        expect(body[CborString('sequence')], isA<CborInt>());
      },
    );

    test(
      // Contract: the audio bytes for a manual-mode one-shot submission
      // (sendAudioOneShot) reach the server without base64 encoding.
      'turn.audio.submit encodes pcm as CBOR bstr',
      () {
        final pcm = Uint8List.fromList(List.generate(8, (i) => i * 10));
        final msg = TurnAudioSubmitMsg(
          messageId: 'msg-002',
          clientItemId: 'item-002',
          pcm: pcm,
          sampleRate: 24000,
          channels: 1,
          bitDepth: 16,
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'turn.audio.submit');
        final pcmField = body[CborString('pcm')];
        expect(
          pcmField,
          isA<CborBytes>(),
          reason: 'pcm must be CBOR bstr for bandwidth efficiency',
        );
        expect((pcmField as CborBytes).bytes, equals(pcm));
        expect((body[CborString('sampleRate')] as CborInt).toInt(), 24000);
        expect((body[CborString('channels')] as CborInt).toInt(), 1);
        expect((body[CborString('bitDepth')] as CborInt).toInt(), 16);
      },
    );

    test(
      // Contract: image bytes the user shares with the AI reach the server as
      // raw bytes so the server can sniff the MIME type from the magic bytes.
      // If they arrived as base64 the magic bytes would be hidden.
      'turn.image.submit encodes imageBytes as CBOR bstr',
      () {
        // Fake PNG magic bytes
        final img = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
        final msg = TurnImageSubmitMsg(
          messageId: 'msg-003',
          clientItemId: 'item-003',
          imageBytes: img,
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'turn.image.submit');
        final imgField = body[CborString('imageBytes')];
        expect(
          imgField,
          isA<CborBytes>(),
          reason: 'imageBytes must be CBOR bstr so server can sniff MIME',
        );
        expect((imgField as CborBytes).bytes, equals(img));
      },
    );

    test(
      // Contract: the session.open message carries the JWT, modelId, and
      // audio format settings so the server can authenticate and configure
      // the realtime session correctly.
      'session.open encodes all required fields',
      () {
        final msg = SessionOpenMsg(
          messageId: 'open-001',
          token: 'jwt.token.here',
          modelId: 'voice-agent-prod',
          voice: 'alloy',
          instructions: 'Be concise.',
          audioTurnMode: 'voice_activity',
          inputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 24000,
            channels: 1,
          ),
          outputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 24000,
            channels: 1,
          ),
          client: {'platform': 'flutter', 'appVersion': '1.0.0'},
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'session.open');
        expect(_textOf(root, 'messageId'), 'open-001');
        expect(_textOf(body, 'token'), 'jwt.token.here');
        expect(_textOf(body, 'modelId'), 'voice-agent-prod');
        expect(_textOf(body, 'voice'), 'alloy');
        expect(_textOf(body, 'instructions'), 'Be concise.');
        expect(_textOf(body, 'audioTurnMode'), 'voice_activity');
        // nested inputAudio
        final inputAudio = body[CborString('inputAudio')] as CborMap;
        expect(_textOf(inputAudio, 'encoding'), 'pcm_s16le');
        expect(
          (inputAudio[CborString('sampleRate')] as CborInt).toInt(),
          24000,
        );
      },
    );

    test(
      // Contract: a session resume request carries the prior sessionId so the
      // server can rebind the user's existing session instead of starting a
      // new one.
      'session.open with resume encodes resume.sessionId',
      () {
        final msg = SessionOpenMsg(
          messageId: 'open-002',
          token: 'jwt.token.here',
          modelId: 'voice-agent-prod',
          instructions: '',
          audioTurnMode: 'voice_activity',
          inputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 24000,
            channels: 1,
          ),
          outputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 24000,
            channels: 1,
          ),
          client: {},
          resume: ResumeRequest(sessionId: 's_01'),
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);
        final resume = body[CborString('resume')] as CborMap;
        expect(_textOf(resume, 'sessionId'), 's_01');
      },
    );

    test(
      // Contract: tool results sent by the user (after executing a function
      // call) include the callId and output so the server can match them to
      // the right AI tool request.
      'tool.result.submit encodes callId, output, disposition',
      () {
        final msg = ToolResultSubmitMsg(
          messageId: 'msg-004',
          clientItemId: 'item-004',
          callId: 'call_01',
          output: '{"ok":true}',
          disposition: 'success',
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'tool.result.submit');
        expect(_textOf(body, 'callId'), 'call_01');
        expect(_textOf(body, 'output'), '{"ok":true}');
        expect(_textOf(body, 'disposition'), 'success');
        // optional errorMessage absent
        expect(body[CborString('errorMessage')], isNull);
      },
    );

    test(
      // Contract: interrupting the AI while it is speaking sends the
      // barge_in reason so the server stops the current generation
      // immediately.
      'assistant.interrupt encodes reason',
      () {
        final msg = AssistantInterruptMsg(reason: 'barge_in');
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'assistant.interrupt');
        expect(_textOf(body, 'reason'), 'barge_in');
        // one-way: no messageId
        expect(root[CborString('messageId')], isNull);
      },
    );

    test(
      // Contract: registering tools with the server sends the complete tool
      // catalog including parameters schema so the AI knows what functions
      // are available.
      'tools.set encodes tool list with parameters',
      () {
        final msg = ToolsSetMsg(
          messageId: 'msg-005',
          tools: [
            ToolSpec(
              name: 'get_weather',
              description: 'Get current weather',
              parameters: {
                'type': 'object',
                'properties': {
                  'city': {'type': 'string'},
                },
              },
            ),
          ],
        );
        final root = _encodeToCborMap(msg);
        final body = _bodyOf(root);

        expect(_textOf(root, 'type'), 'tools.set');
        final tools = body[CborString('tools')] as CborList;
        expect(tools, hasLength(1));
        final tool = tools[0] as CborMap;
        expect(_textOf(tool, 'name'), 'get_weather');
        expect(_textOf(tool, 'description'), 'Get current weather');
        expect(tool[CborString('parameters')], isA<CborMap>());
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // S2C decode
  // ─────────────────────────────────────────────────────────────────────────

  group('VhrpCborCodec — S2C decode', () {
    test(
      // Contract: when the session is established the app learns the
      // sessionId (needed for resume), threadId, and which extensions the
      // server supports — all of which are needed before the user can speak.
      'session.ready decodes sessionId, threadId, capabilityExtensions',
      () {
        final msg = _decodeS2c('session.ready', {
          'sessionId': CborString('s_01'),
          'threadId': CborString('t_01'),
          'conversationId': CborString('c_01'),
          'capabilities': CborMap({
            CborString('extensions'): CborList([
              CborString('session.voice_selection'),
              CborString('session.reasoning_effort_selection'),
            ]),
          }),
        }, replyTo: 'open-001');

        expect(msg, isA<SessionReadyMsg>());
        final ready = msg as SessionReadyMsg;
        expect(ready.replyTo, 'open-001');
        expect(ready.sessionId, 's_01');
        expect(ready.threadId, 't_01');
        expect(ready.conversationId, 'c_01');
        expect(
          ready.capabilityExtensions,
          containsAll([
            'session.voice_selection',
            'session.reasoning_effort_selection',
          ]),
        );
      },
    );

    test(
      // Contract: when the user reconnects after a network drop, the app
      // learns the resume succeeded and can proceed to request a thread
      // snapshot to restore conversation state.
      'session.resumed decodes sessionId, threadId, conversationId',
      () {
        final msg = _decodeS2c('session.resumed', {
          'sessionId': CborString('s_01'),
          'threadId': CborString('t_01'),
          'conversationId': CborString('c_01'),
        }, replyTo: 'open-002');

        expect(msg, isA<SessionResumedMsg>());
        final resumed = msg as SessionResumedMsg;
        expect(resumed.replyTo, 'open-002');
        expect(resumed.sessionId, 's_01');
      },
    );

    test(
      // Contract: the app can confirm that a user action (e.g. sending text)
      // was accepted by the server by checking the ack.
      'ack decodes accepted, applied, clientItemId',
      () {
        final msg = _decodeS2c('ack', {
          'accepted': CborBool(true),
          'clientItemId': CborString('item-001'),
          'applied': CborBool(true),
        }, replyTo: 'msg-001');

        expect(msg, isA<AckMsg>());
        final ack = msg as AckMsg;
        expect(ack.replyTo, 'msg-001');
        expect(ack.accepted, isTrue);
        expect(ack.clientItemId, 'item-001');
        expect(ack.applied, isTrue);
      },
    );

    test(
      // Contract: when the user reconnects or triggers a resync, the app
      // receives a full thread snapshot so it can restore the complete
      // conversation history without losing any messages.
      'thread.snapshot decodes threadId, items list',
      () {
        final msg = _decodeS2c('thread.snapshot', {
          'threadId': CborString('t_01'),
          'conversationId': CborString('c_01'),
          'items': CborList([
            CborMap({
              CborString('id'): CborString('item_a'),
              CborString('type'): CborString('message'),
              CborString('role'): CborString('assistant'),
              CborString('status'): CborString('completed'),
            }),
          ]),
        });

        expect(msg, isA<ThreadSnapshotMsg>());
        final snap = msg as ThreadSnapshotMsg;
        expect(snap.threadId, 't_01');
        expect(snap.conversationId, 'c_01');
        expect(snap.items, hasLength(1));
        expect(snap.items[0]['id'], 'item_a');
        expect(snap.items[0]['type'], 'message');
      },
    );

    test(
      // Contract: as the AI writes a response, each patch operation updates
      // the on-screen conversation in real time.  The full sequence of
      // add_item → put_part → append_text → set_status must round-trip so
      // the user sees the message appear and build up incrementally.
      'thread.patch decodes multiple op types',
      () {
        final msg = _decodeS2c('thread.patch', {
          'ops': CborList([
            CborMap({
              CborString('op'): CborString('add_item'),
              CborString('item'): CborMap({
                CborString('id'): CborString('item_a'),
                CborString('type'): CborString('message'),
                CborString('role'): CborString('assistant'),
                CborString('status'): CborString('in_progress'),
              }),
            }),
            CborMap({
              CborString('op'): CborString('put_part'),
              CborString('itemId'): CborString('item_a'),
              CborString('contentIndex'): CborSmallInt(0),
              CborString('part'): CborMap({
                CborString('type'): CborString('text'),
                CborString('isDone'): CborBool(false),
              }),
            }),
            CborMap({
              CborString('op'): CborString('append_text'),
              CborString('itemId'): CborString('item_a'),
              CborString('contentIndex'): CborSmallInt(0),
              CborString('delta'): CborString('こんにちは'),
            }),
            CborMap({
              CborString('op'): CborString('set_status'),
              CborString('itemId'): CborString('item_a'),
              CborString('status'): CborString('completed'),
            }),
          ]),
        });

        expect(msg, isA<ThreadPatchMsg>());
        final patch = msg as ThreadPatchMsg;
        expect(patch.ops, hasLength(4));

        // add_item
        expect(patch.ops[0], isA<AddItemOp>());
        final addOp = patch.ops[0] as AddItemOp;
        expect(addOp.item['id'], 'item_a');
        expect(addOp.item['role'], 'assistant');

        // put_part
        expect(patch.ops[1], isA<PutPartOp>());
        final putOp = patch.ops[1] as PutPartOp;
        expect(putOp.itemId, 'item_a');
        expect(putOp.contentIndex, 0);
        expect(putOp.part['type'], 'text');

        // append_text
        expect(patch.ops[2], isA<AppendTextOp>());
        final appendOp = patch.ops[2] as AppendTextOp;
        expect(appendOp.itemId, 'item_a');
        expect(appendOp.delta, 'こんにちは');

        // set_status
        expect(patch.ops[3], isA<SetStatusOp>());
        final statusOp = patch.ops[3] as SetStatusOp;
        expect(statusOp.itemId, 'item_a');
        expect(statusOp.status, 'completed');
      },
    );

    test(
      // Contract: thread.patch with set_conversation_id, set_role,
      // set_field, remove_item, replace_text, append_transcript,
      // replace_transcript all decode correctly so conversation state
      // updates don't get silently dropped.
      'thread.patch decodes remaining op types',
      () {
        final msg = _decodeS2c('thread.patch', {
          'ops': CborList([
            CborMap({
              CborString('op'): CborString('set_conversation_id'),
              CborString('conversationId'): CborString('c_99'),
            }),
            CborMap({
              CborString('op'): CborString('set_role'),
              CborString('itemId'): CborString('item_b'),
              CborString('role'): CborString('user'),
            }),
            CborMap({
              CborString('op'): CborString('set_field'),
              CborString('itemId'): CborString('item_b'),
              CborString('field'): CborString('callId'),
              CborString('value'): CborString('call_42'),
            }),
            CborMap({
              CborString('op'): CborString('remove_item'),
              CborString('itemId'): CborString('item_old'),
            }),
            CborMap({
              CborString('op'): CborString('replace_text'),
              CborString('itemId'): CborString('item_c'),
              CborString('contentIndex'): CborSmallInt(0),
              CborString('text'): CborString('Final text'),
            }),
            CborMap({
              CborString('op'): CborString('append_transcript'),
              CborString('itemId'): CborString('item_d'),
              CborString('contentIndex'): CborSmallInt(1),
              CborString('delta'): CborString('Hello'),
            }),
            CborMap({
              CborString('op'): CborString('replace_transcript'),
              CborString('itemId'): CborString('item_d'),
              CborString('contentIndex'): CborSmallInt(1),
              CborString('text'): CborString('Hello world'),
            }),
          ]),
        });

        final patch = msg as ThreadPatchMsg;
        expect(patch.ops[0], isA<SetConversationIdOp>());
        expect((patch.ops[0] as SetConversationIdOp).conversationId, 'c_99');

        expect(patch.ops[1], isA<SetRoleOp>());
        expect((patch.ops[1] as SetRoleOp).role, 'user');

        expect(patch.ops[2], isA<SetFieldOp>());
        final setField = patch.ops[2] as SetFieldOp;
        expect(setField.field, 'callId');
        expect(setField.value, 'call_42');

        expect(patch.ops[3], isA<RemoveItemOp>());
        expect((patch.ops[3] as RemoveItemOp).itemId, 'item_old');

        expect(patch.ops[4], isA<ReplaceTextOp>());
        expect((patch.ops[4] as ReplaceTextOp).text, 'Final text');

        expect(patch.ops[5], isA<AppendTranscriptOp>());
        expect((patch.ops[5] as AppendTranscriptOp).delta, 'Hello');

        expect(patch.ops[6], isA<ReplaceTranscriptOp>());
        expect((patch.ops[6] as ReplaceTranscriptOp).text, 'Hello world');
      },
    );

    test(
      // Contract: the AI's spoken response arrives as raw PCM bytes so the
      // app can play it without decoding overhead.  If the bytes were
      // base64-encoded the playback would require an extra decode step that
      // adds latency between the AI "speaking" and the user hearing it.
      'assistant.audio.chunk decodes pcm as raw Uint8List (no base64)',
      () {
        final pcmBytes = Uint8List.fromList([0x00, 0x01, 0xFF, 0x80]);
        final msg = _decodeS2c('assistant.audio.chunk', {
          'itemId': CborString('item_a'),
          'contentIndex': CborSmallInt(1),
          'pcm': CborBytes(pcmBytes),
        });

        expect(msg, isA<AssistantAudioChunkMsg>());
        final chunk = msg as AssistantAudioChunkMsg;
        expect(chunk.itemId, 'item_a');
        expect(chunk.contentIndex, 1);
        // The decoded pcm must equal the original raw bytes exactly
        expect(
          chunk.pcm,
          equals(pcmBytes),
          reason: 'PCM bytes must survive CBOR bstr round-trip without base64',
        );
        expect(chunk.pcm, isA<Uint8List>());
      },
    );

    test(
      // Contract: the app knows when the AI has finished speaking so it can
      // fire assistantAudioCompleted and allow the user to speak again.
      'assistant.audio.done decodes itemId and contentIndex',
      () {
        final msg = _decodeS2c('assistant.audio.done', {
          'itemId': CborString('item_a'),
          'contentIndex': CborSmallInt(1),
        });

        expect(msg, isA<AssistantAudioDoneMsg>());
        final done = msg as AssistantAudioDoneMsg;
        expect(done.itemId, 'item_a');
        expect(done.contentIndex, 1);
      },
    );

    test(
      // Contract: the app reflects VAD state so the UI can show the user
      // whether they are currently being heard (speaking indicator).
      'vad.state decodes isSpeaking',
      () {
        final msgTrue = _decodeS2c('vad.state', {'isSpeaking': CborBool(true)});
        expect((msgTrue as VadStateMsg).isSpeaking, isTrue);

        final msgFalse = _decodeS2c('vad.state', {
          'isSpeaking': CborBool(false),
        });
        expect((msgFalse as VadStateMsg).isSpeaking, isFalse);
      },
    );

    test(
      // Contract: error messages from the server include a machine-readable
      // code and a human-readable message so the app can both react
      // programmatically (e.g. close on non-recoverable) and show the user
      // a meaningful error.
      'error decodes code, message, recoverable, optional replyTo',
      () {
        final msg = _decodeS2c('error', {
          'code': CborString('media.unsupported_image'),
          'message': CborString('Unsupported image format.'),
          'recoverable': CborBool(true),
        }, replyTo: 'msg-003');

        expect(msg, isA<ErrorMsg>());
        final err = msg as ErrorMsg;
        expect(err.replyTo, 'msg-003');
        expect(err.code, 'media.unsupported_image');
        expect(err.message, 'Unsupported image format.');
        expect(err.recoverable, isTrue);
      },
    );

    test(
      // Contract: an unrecoverable error (server will close the connection)
      // is decoded correctly so the adapter can trigger proper disconnection
      // handling before the WebSocket closes.
      'error with recoverable=false decodes correctly',
      () {
        final msg = _decodeS2c('error', {
          'code': CborString('auth.invalid_jwt'),
          'message': CborString('Token expired'),
          'recoverable': CborBool(false),
        });

        final err = msg as ErrorMsg;
        expect(err.recoverable, isFalse);
        expect(err.replyTo, isNull);
      },
    );

    test(
      // Contract: if the server sends a message type this client does not
      // implement, the frame must fail loudly. Silently converting it to an
      // ignored placeholder would make implemented protocol messages behave as
      // implicit stubs and hide compatibility bugs from the user.
      'unknown type fails decode instead of becoming a silent stub',
      () {
        expect(
          () => _decodeS2c('future.unknown.type', {
            'someField': CborString('someValue'),
          }),
          throwsA(
            isA<VhrpCborDecodeException>().having(
              (e) => e.message,
              'message',
              contains('Unsupported VHRP S2C message type'),
            ),
          ),
        );
      },
    );

    test(
      // Contract: if the server sends a thread.patch with an op the client
      // does not recognise, the remaining ops in the patch are still decoded
      // and the unknown op is represented as UnknownOp so the adapter can
      // choose to send thread.sync.request for recovery.
      'thread.patch with unknown op is decoded as UnknownOp',
      () {
        final msg = _decodeS2c('thread.patch', {
          'ops': CborList([
            CborMap({
              CborString('op'): CborString('future_op'),
              CborString('itemId'): CborString('item_x'),
            }),
            CborMap({
              CborString('op'): CborString('set_status'),
              CborString('itemId'): CborString('item_a'),
              CborString('status'): CborString('completed'),
            }),
          ]),
        });

        final patch = msg as ThreadPatchMsg;
        expect(patch.ops[0], isA<UnknownOp>());
        expect((patch.ops[0] as UnknownOp).unknownOp, 'future_op');
        // subsequent op is still decoded correctly
        expect(patch.ops[1], isA<SetStatusOp>());
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Decode error cases
  // ─────────────────────────────────────────────────────────────────────────

  group('VhrpCborCodec — decode error cases', () {
    test(
      // Contract: a malformed binary frame (corrupted network data) throws a
      // VhrpCborDecodeException — not an unhandled error — so the adapter
      // can cleanly handle the failure.
      'non-CBOR bytes throw VhrpCborDecodeException',
      () {
        final garbage = Uint8List.fromList([0xFF, 0xFF, 0xFF]);
        expect(
          () => _codec.decode(garbage),
          throwsA(isA<VhrpCborDecodeException>()),
        );
      },
    );

    test(
      // Contract: a CBOR frame that is not a map (e.g. a stray array) throws
      // VhrpCborDecodeException so the adapter handles it gracefully.
      'CBOR non-map throws VhrpCborDecodeException',
      () {
        final cborArray = Uint8List.fromList(
          cbor.encode(CborList([CborString('hello')])),
        );
        expect(
          () => _codec.decode(cborArray),
          throwsA(isA<VhrpCborDecodeException>()),
        );
      },
    );

    test(
      // Contract: a CBOR map missing the required "type" field throws
      // VhrpCborDecodeException.
      'missing type field throws VhrpCborDecodeException',
      () {
        final noType = Uint8List.fromList(
          cbor.encode(CborMap({CborString('body'): CborMap({})})),
        );
        expect(
          () => _codec.decode(noType),
          throwsA(isA<VhrpCborDecodeException>()),
        );
      },
    );

    test(
      // Contract: a CBOR map missing the required "body" field throws
      // VhrpCborDecodeException.
      'missing body field throws VhrpCborDecodeException',
      () {
        final noBody = Uint8List.fromList(
          cbor.encode(
            CborMap({CborString('type'): CborString('session.ready')}),
          ),
        );
        expect(
          () => _codec.decode(noBody),
          throwsA(isA<VhrpCborDecodeException>()),
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Full round-trip (encode C2S then re-parse with cbor.decode to verify)
  // ─────────────────────────────────────────────────────────────────────────

  group('VhrpCborCodec — full round-trip invariants', () {
    test(
      // Contract: every byte in the original PCM recording survives the
      // encode→decode cycle intact.  A single flipped bit would corrupt
      // audio quality.
      'audio bytes survive encode/re-decode byte-for-byte',
      () {
        // Create a buffer with a range of byte values including edge cases
        final original = Uint8List.fromList([
          0x00,
          0x7F,
          0x80,
          0xFF,
          0x01,
          0xFE,
        ]);
        final msg = LiveAudioChunkMsg(pcm: original, sequence: 1);
        final bytes = _codec.encode(msg);

        // Re-parse the CBOR bytes independently
        final root = cbor.decode(bytes) as CborMap;
        final body = root[CborString('body')] as CborMap;
        final pcmField = body[CborString('pcm')] as CborBytes;
        expect(Uint8List.fromList(pcmField.bytes), equals(original));
      },
    );

    test(
      // Contract: image bytes survive encode with exact byte-for-byte
      // fidelity.  Any mutation would make the magic bytes unrecognisable
      // to the MIME sniffer.
      'image bytes survive encode/re-decode byte-for-byte',
      () {
        final original = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        final msg = TurnImageSubmitMsg(
          messageId: 'r-001',
          clientItemId: 'ci-001',
          imageBytes: original,
        );
        final bytes = _codec.encode(msg);

        final root = cbor.decode(bytes) as CborMap;
        final body = root[CborString('body')] as CborMap;
        final imgField = body[CborString('imageBytes')] as CborBytes;
        expect(Uint8List.fromList(imgField.bytes), equals(original));
      },
    );

    test(
      // Contract: text content (user messages) survives the full encode cycle
      // including multi-byte Unicode characters so the AI receives exactly
      // what the user typed.
      'text fields survive encode/re-decode with Unicode intact',
      () {
        const text = '日本語テスト 🎙️';
        final msg = TurnTextSubmitMsg(
          messageId: 'r-002',
          clientItemId: 'ci-002',
          text: text,
        );
        final bytes = _codec.encode(msg);

        final root = cbor.decode(bytes) as CborMap;
        final body = root[CborString('body')] as CborMap;
        expect((body[CborString('text')] as CborString).toString(), text);
      },
    );
  });

  // ── _dartToCbor nested-map regression (Fix 1) ───────────────────────────

  group('_dartToCbor nested map encoding (regression: const/dynamic map)', () {
    test(
      // Regression: const map with type _ConstMap<dynamic,dynamic> must be
      // encoded as a CBOR map, not stringified via value.toString().
      // Before fix: properties:{} encoded as CborString("{}").
      // After fix:  properties:{} encoded as CborMap({}).
      'const empty map {properties:{}} encodes as CBOR map, not string "{}"',
      () {
        const schema = {'type': 'object', 'properties': <String, dynamic>{}};
        final msg = ToolsSetMsg(
          messageId: 'regression-001',
          tools: [
            ToolSpec(
              name: 'fs_active_files',
              description: 'test',
              parameters: Map<String, Object?>.from(schema),
            ),
          ],
        );
        final root = _encodeToCborMap(msg);
        final body = root[CborString('body')] as CborMap;
        final toolsList = body[CborString('tools')] as CborList;
        final toolMap = toolsList[0] as CborMap;
        final params = toolMap[CborString('parameters')];

        // parameters must be a CborMap, not a CborString
        expect(
          params,
          isA<CborMap>(),
          reason:
              'parameters must be a CBOR map, not CborString("{}").'
              ' Got: ${params.runtimeType} = $params',
        );

        final paramsMap = params as CborMap;
        final typeValue = paramsMap[CborString('type')];
        expect(
          (typeValue as CborString).toString(),
          'object',
          reason: 'type field must be "object"',
        );

        final propertiesValue = paramsMap[CborString('properties')];
        expect(
          propertiesValue,
          isA<CborMap>(),
          reason:
              'properties must be a CBOR map, not a string.'
              ' Got: ${propertiesValue.runtimeType} = $propertiesValue',
        );
        expect(
          (propertiesValue as CborMap).isEmpty,
          isTrue,
          reason: 'properties must be an empty CBOR map for a no-arg tool',
        );
      },
    );

    test(
      'deeply nested dynamic map encodes as nested CBOR map (not string)',
      () {
        // Simulate a real tool with nested schema like get_weather
        final schema = <String, Object?>{
          'type': 'object',
          'properties': <dynamic, dynamic>{
            'city': <String, dynamic>{'type': 'string'},
          },
          'required': <dynamic>['city'],
        };
        final msg = ToolsSetMsg(
          messageId: 'regression-002',
          tools: [
            ToolSpec(
              name: 'get_weather',
              description: 'test',
              parameters: schema,
            ),
          ],
        );
        final root = _encodeToCborMap(msg);
        final body = root[CborString('body')] as CborMap;
        final toolsList = body[CborString('tools')] as CborList;
        final toolMap = toolsList[0] as CborMap;
        final params = toolMap[CborString('parameters')] as CborMap;
        final props = params[CborString('properties')] as CborMap;
        final cityNode = props[CborString('city')];

        expect(
          cityNode,
          isA<CborMap>(),
          reason: 'nested property schema must be CborMap',
        );
      },
    );

    test('empty top-level map {} encodes as empty CBOR map', () {
      final msg = ToolsSetMsg(
        messageId: 'regression-003',
        tools: [
          ToolSpec(
            name: 'no_schema_tool',
            description: 'test',
            parameters: const <String, Object?>{},
          ),
        ],
      );
      final root = _encodeToCborMap(msg);
      final body = root[CborString('body')] as CborMap;
      final toolsList = body[CborString('tools')] as CborList;
      final toolMap = toolsList[0] as CborMap;
      final params = toolMap[CborString('parameters')];

      expect(
        params,
        isA<CborMap>(),
        reason: 'empty parameters map must be CBOR map, not string.',
      );
      expect((params as CborMap).isEmpty, isTrue);
    });
  });
}
