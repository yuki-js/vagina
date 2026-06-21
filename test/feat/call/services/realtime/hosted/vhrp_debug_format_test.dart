// Unit tests for VhrpDebugFormat — the BLOB-safe VHRP message formatter.
//
// Key contracts verified here:
//
//   F1  BLOB fields (pcm, imageBytes) are replaced with `<bytes: N>` and
//       the raw bytes are NEVER present in the output.
//
//   F2  Text fields are present and readable in the output.
//
//   F3  Long strings are truncated to maxStringLength with `…`.
//
//   F4  Nested byte-string values inside opaque maps (add_item.item,
//       put_part.part, thread.snapshot items) are also replaced with
//       `<bytes: N>` — no raw bytes escape through nested structures.
//
//   F5  All known C2S message types produce output containing the `type`
//       string (smoke test for exhaustive coverage).
//
//   F6  All known S2C message types produce output containing the `type`
//       string (smoke test for exhaustive coverage).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_debug_format.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a [Uint8List] of [length] bytes.
Uint8List _pcm(int length) => Uint8List(length);

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── F1: BLOB fields produce <bytes: N>, raw bytes NEVER appear ─────────────

  group('F1 — BLOB fields are replaced with <bytes: N>', () {
    test(
      // Contract F1a: live.audio.chunk pcm must not appear raw; only a length
      // summary is emitted so the log is not flooded with binary data.
      'LiveAudioChunkMsg.pcm → <bytes: N>',
      () {
        final pcm = _pcm(12345);
        final out = VhrpDebugFormat.formatC2s(
          LiveAudioChunkMsg(pcm: pcm, sequence: 7),
        );
        expect(out, contains('<bytes: 12345>'),
            reason: 'F1a: must emit byte summary');
        // The raw bytes must NOT appear as decimal integers, base64, or hex runs
        expect(out.contains('0, 0, 0'), isFalse,
            reason: 'F1a: raw byte sequence must not be in output');
      },
    );

    test(
      // Contract F1b: turn.audio.submit pcm must not appear raw.
      'TurnAudioSubmitMsg.pcm → <bytes: N>',
      () {
        final pcm = _pcm(48000);
        final out = VhrpDebugFormat.formatC2s(
          TurnAudioSubmitMsg(
            messageId: 'msg-1',
            clientItemId: 'ci-1',
            pcm: pcm,
            sampleRate: 24000,
            channels: 1,
            bitDepth: 16,
          ),
        );
        expect(out, contains('<bytes: 48000>'),
            reason: 'F1b: pcm length summary must be present');
        expect(out.contains('0, 0'), isFalse,
            reason: 'F1b: raw bytes must not appear');
      },
    );

    test(
      // Contract F1c: turn.image.submit imageBytes must not appear raw.
      'TurnImageSubmitMsg.imageBytes → <bytes: N>',
      () {
        // Fake PNG magic bytes — must NOT appear in the log output
        final imgBytes = Uint8List.fromList(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        );
        final out = VhrpDebugFormat.formatC2s(
          TurnImageSubmitMsg(
            messageId: 'msg-2',
            clientItemId: 'ci-2',
            imageBytes: imgBytes,
          ),
        );
        expect(out, contains('<bytes: 8>'),
            reason: 'F1c: imageBytes length summary must be present');
        // 0x89 = 137 in decimal; 0x50 = 80.  Neither should appear as a
        // formatted byte sequence.
        expect(out.contains('137'), isFalse,
            reason: 'F1c: raw byte values must not appear');
      },
    );

    test(
      // Contract F1d: assistant.audio.chunk pcm must not appear raw (S2C).
      'AssistantAudioChunkMsg.pcm → <bytes: N>',
      () {
        final pcm = _pcm(3200);
        final out = VhrpDebugFormat.formatS2c(
          AssistantAudioChunkMsg(
            itemId: 'item-1',
            contentIndex: 0,
            pcm: pcm,
          ),
        );
        expect(out, contains('<bytes: 3200>'),
            reason: 'F1d: pcm length summary must be present');
      },
    );
  });

  // ── F2: Text fields are readable in output ────────────────────────────────

  group('F2 — text fields appear in output', () {
    test(
      'TurnTextSubmitMsg includes text content',
      () {
        const text = 'Hello, VHRP!';
        final out = VhrpDebugFormat.formatC2s(
          TurnTextSubmitMsg(
            messageId: 'msg-3',
            clientItemId: 'ci-3',
            text: text,
          ),
        );
        expect(out, contains('turn.text.submit'),
            reason: 'F2: type string must be in output');
        expect(out, contains(text),
            reason: 'F2: text content must be in output');
        expect(out, contains('msg-3'),
            reason: 'F2: messageId must be in output');
      },
    );

    test(
      'ErrorMsg includes code and message',
      () {
        final out = VhrpDebugFormat.formatS2c(
          ErrorMsg(
            replyTo: 'req-1',
            code: 'auth.invalid_jwt',
            message: 'Token expired.',
            recoverable: false,
          ),
        );
        expect(out, contains('error'), reason: 'F2: type string');
        expect(out, contains('auth.invalid_jwt'), reason: 'F2: code');
        expect(out, contains('Token expired.'), reason: 'F2: message');
        expect(out, contains('false'), reason: 'F2: recoverable');
      },
    );

    test(
      'SessionReadyMsg includes sessionId and threadId',
      () {
        final out = VhrpDebugFormat.formatS2c(
          SessionReadyMsg(
            replyTo: 'open-1',
            sessionId: 'srv-session-001',
            threadId: 'srv-thread-001',
            capabilityExtensions: ['session.voice_selection'],
          ),
        );
        expect(out, contains('session.ready'));
        expect(out, contains('srv-session-001'));
        expect(out, contains('srv-thread-001'));
        expect(out, contains('session.voice_selection'));
      },
    );
  });

  // ── F3: Long strings are truncated ───────────────────────────────────────

  group('F3 — long strings are truncated', () {
    test(
      // Contract F3: very long text (e.g. transcript, instructions) is cut to
      // maxStringLength so logs stay readable.
      'text longer than maxStringLength is truncated with ellipsis',
      () {
        final longText = 'A' * (VhrpDebugFormat.maxStringLength + 100);
        final out = VhrpDebugFormat.formatC2s(
          TurnTextSubmitMsg(
            messageId: 'msg-4',
            clientItemId: 'ci-4',
            text: longText,
          ),
        );
        // Output must contain the truncation marker
        expect(out, contains('…'), reason: 'F3: truncation marker must appear');
        // And the full long text must NOT be present
        expect(out.contains(longText), isFalse,
            reason: 'F3: full long text must not appear');
        // The first maxStringLength chars should still be there
        expect(
          out.contains('A' * VhrpDebugFormat.maxStringLength),
          isTrue,
          reason: 'F3: first maxStringLength chars must be present',
        );
      },
    );

    test(
      'text at exactly maxStringLength is NOT truncated',
      () {
        final exactText = 'B' * VhrpDebugFormat.maxStringLength;
        final out = VhrpDebugFormat.formatC2s(
          TurnTextSubmitMsg(
            messageId: 'msg-5',
            clientItemId: 'ci-5',
            text: exactText,
          ),
        );
        expect(out, contains(exactText),
            reason: 'F3: text at exactly maxStringLength should not be cut');
        expect(out.contains('…'), isFalse,
            reason: 'F3: no truncation marker for exact-length text');
      },
    );
  });

  // ── F4: Nested byte strings inside maps are sanitised ─────────────────────

  group('F4 — byte strings nested in opaque maps are replaced with <bytes: N>',
      () {
    test(
      // Contract F4: thread.patch → add_item whose item map contains a bytes
      // field must produce a <bytes: N> summary, not raw bytes.
      'AddItemOp with bytes field in item map',
      () {
        final fakeAudioData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
        final op = AddItemOp(
          item: {
            'id': 'item-audio',
            'type': 'message',
            'role': 'assistant',
            // Hypothetical audio bytes nested in the item map
            'audioPreview': fakeAudioData,
          },
        );
        final msg = ThreadPatchMsg(ops: [op]);
        final out = VhrpDebugFormat.formatS2c(msg);

        // The bytes must be summarised, NOT printed raw
        expect(out.contains('1, 2, 3'), isFalse,
            reason: 'F4: raw byte sequence inside nested map must not appear');
        // The item id should still be visible
        expect(out, contains('item-audio'),
            reason: 'F4: item id must appear in output');
      },
    );

    test(
      // Contract F4b: PutPartOp part map with bytes must also be sanitised.
      'PutPartOp with bytes field in part map',
      () {
        final fakeBytes = Uint8List.fromList(List.generate(256, (i) => i % 256));
        final op = PutPartOp(
          itemId: 'item-1',
          contentIndex: 0,
          part: {
            'type': 'audio',
            'rawAudio': fakeBytes,
          },
        );
        final msg = ThreadPatchMsg(ops: [op]);
        final out = VhrpDebugFormat.formatS2c(msg);

        // Raw bytes must not appear
        expect(out.contains('0, 1, 2'), isFalse,
            reason: 'F4b: raw bytes in part map must not appear');
      },
    );

    test(
      // Contract F4c: deeply nested bytes (bytes inside a list inside a map).
      'bytes nested inside a list inside a map are sanitised',
      () {
        final fakeBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final op = AddItemOp(
          item: {
            'id': 'item-x',
            'chunks': [fakeBytes, 'some text'],
          },
        );
        final msg = ThreadPatchMsg(ops: [op]);
        final out = VhrpDebugFormat.formatS2c(msg);

        // 0xDE = 222, 0xAD = 173 — neither raw value should appear
        expect(out.contains('222'), isFalse,
            reason: 'F4c: raw bytes in nested list must not appear');
        expect(out.contains('173'), isFalse,
            reason: 'F4c: raw bytes in nested list must not appear');
      },
    );
  });

  // ── F5: All C2S types produce output with type string ─────────────────────

  group('F5 — all C2S types produce readable output', () {
    final dummyAudioFormat = AudioFormat(
      encoding: 'pcm_s16le',
      sampleRate: 24000,
      channels: 1,
    );

    final cases = <(String, VhrpC2sMessage)>[
      (
        'session.open',
        SessionOpenMsg(
          messageId: 'x',
          token: 'tok',
          modelId: 'model-v1',
          audioTurnMode: 'voice_activity',
          inputAudio: dummyAudioFormat,
          outputAudio: dummyAudioFormat,
          client: {},
        ),
      ),
      (
        'audio.turn.mode.set',
        AudioTurnModeSetMsg(mode: 'manual'),
      ),
      (
        'session.instructions.set',
        SessionInstructionsSetMsg(messageId: 'x', instructions: 'Be brief.'),
      ),
      (
        'live.audio.chunk',
        LiveAudioChunkMsg(pcm: _pcm(160), sequence: 1),
      ),
      (
        'turn.audio.submit',
        TurnAudioSubmitMsg(
          messageId: 'x',
          clientItemId: 'ci',
          pcm: _pcm(4800),
          sampleRate: 24000,
          channels: 1,
          bitDepth: 16,
        ),
      ),
      (
        'turn.text.submit',
        TurnTextSubmitMsg(messageId: 'x', clientItemId: 'ci', text: 'hi'),
      ),
      (
        'turn.image.submit',
        TurnImageSubmitMsg(
          messageId: 'x',
          clientItemId: 'ci',
          imageBytes: _pcm(1024),
        ),
      ),
      (
        'tools.set',
        ToolsSetMsg(
          messageId: 'x',
          tools: [
            ToolSpec(name: 'foo', description: 'bar', parameters: {}),
          ],
        ),
      ),
      (
        'session.extension.apply',
        SessionExtensionApplyMsg(
          messageId: 'x',
          extensionType: 'ext.voice',
          payload: {},
        ),
      ),
      (
        'tool.result.submit',
        ToolResultSubmitMsg(
          messageId: 'x',
          clientItemId: 'ci',
          callId: 'call-1',
          output: '{}',
          disposition: 'success',
        ),
      ),
      (
        'assistant.interrupt',
        AssistantInterruptMsg(reason: 'barge_in'),
      ),
      (
        'thread.sync.request',
        ThreadSyncRequestMsg(messageId: 'x', reason: 'patch_apply_failed'),
      ),
    ];

    for (final (typeStr, msg) in cases) {
      test('$typeStr output contains type string', () {
        final out = VhrpDebugFormat.formatC2s(msg);
        expect(out, contains(typeStr),
            reason: 'F5: formatC2s for $typeStr must contain type string');
        expect(out, isNotEmpty,
            reason: 'F5: output must not be empty');
      });
    }
  });

  // ── F6: All S2C types produce output with type string ─────────────────────

  group('F6 — all S2C types produce readable output', () {
    final cases = <(String, VhrpS2cMessage)>[
      (
        'session.ready',
        SessionReadyMsg(
          sessionId: 's1',
          threadId: 't1',
          capabilityExtensions: [],
        ),
      ),
      (
        'session.resumed',
        SessionResumedMsg(sessionId: 's1', threadId: 't1'),
      ),
      (
        'ack',
        AckMsg(accepted: true, applied: true),
      ),
      (
        'thread.snapshot',
        ThreadSnapshotMsg(threadId: 't1', items: []),
      ),
      (
        'thread.patch',
        ThreadPatchMsg(
          ops: [SetStatusOp(itemId: 'i1', status: 'completed')],
        ),
      ),
      (
        'assistant.audio.chunk',
        AssistantAudioChunkMsg(itemId: 'i1', contentIndex: 0, pcm: _pcm(3200)),
      ),
      (
        'assistant.audio.done',
        AssistantAudioDoneMsg(itemId: 'i1', contentIndex: 0),
      ),
      (
        'vad.state',
        VadStateMsg(isSpeaking: true),
      ),
      (
        'error',
        ErrorMsg(code: 'some.err', message: 'oops', recoverable: true),
      ),
      (
        'unknown',
        UnknownTypeS2cMsg(unknownType: 'future.type', rawEnvelope: {}),
      ),
    ];

    for (final (typeStr, msg) in cases) {
      test('$typeStr output contains type string', () {
        final out = VhrpDebugFormat.formatS2c(msg);
        expect(out, contains(typeStr),
            reason: 'F6: formatS2c for $typeStr must contain type string');
        expect(out, isNotEmpty,
            reason: 'F6: output must not be empty');
      });
    }
  });
}
