// Cross-codec compatibility layer-1 — C2S fixture generator (Dart → Java).
//
// ══════════════════════════════════════════════════════════════════════════════
// PURPOSE & CONTRACT
// ══════════════════════════════════════════════════════════════════════════════
//
// This file encodes representative C2S VHRP messages using the Dart codec
// [VhrpCborCodec.encode()] and writes the raw CBOR bytes plus a companion
// JSON expectation file to `.private.local/vhrp_fixtures/c2s/`.
//
// The Java-side layer-1 test (`VhrpC2sFixtureTest.java`) reads those `.cbor`
// files and decodes them with `VhrpCborCodec.decode(Buffer)`, asserting field
// values against the companion `.json`.  If the two codecs are interoperable,
// every fixture decodes cleanly on the Java side.
//
// ── Interoperability contracts guarded here ──────────────────────────────────
// C1. Binary payloads (PCM, imageBytes) are encoded as CBOR `bstr` (major
//     type 2).  If Dart accidentally encoded them as base64 `tstr`, Java's
//     `node.isBinary()` check in `VhrpCborCodec.bytes()` would return false
//     and the server would receive an empty byte[].  User's voice / image
//     would be silently discarded.
// C2. Text strings are CBOR `tstr` (major type 3).  Mismatching to int would
//     cause `node.isTextual()` to return false on the Java side, dropping the
//     field.
// C3. Map keys are CBOR `tstr`, not int.  Jackson CBOR reads int keys as
//     numeric node names, which do not match the string field selectors in
//     `VhrpCborCodec`.
// C4. Large integers (e.g. sequence ≥ 2^31) must be decoded on the Java side
//     via `asLong()` (which is what `VhrpCborCodec.longValue()` uses).
//     `CborSmallInt` encodes all Dart `int` values faithfully; CBOR int range
//     is -2^64..2^64-1, which Jackson reads correctly.
// C5. Null optional fields must be absent (not CBOR null) in the encoded
//     output.  `_putTextNullable()` ensures this; a stray CBOR null would be
//     seen as a non-textual node on the Java side.
// C6. Non-ASCII Unicode text (Japanese etc.) survives UTF-8 CBOR `tstr`
//     round-trip without garbling.
//
// ── fixture format ──────────────────────────────────────────────────────────
// • One file pair per variant:  <name>.cbor (raw CBOR binary) + <name>.json
//   (human-readable expected decoded values for Java-side assertion).
// • Fixture directory: `../.private.local/vhrp_fixtures/c2s/`
//   resolved relative to the `client/` package root (CWD when running
//   `flutter test` from `client/`).
// • JSON convention:
//   - All field values are their natural JSON type (string, number, bool,
//     object, array).
//   - Fields whose wire type is CBOR `bstr` are represented as lowercase
//     hex strings (no `0x` prefix) in the JSON.
//   - A top-level `"_bstr_fields"` array lists the dot-path of every bstr
//     field so the Java test knows which JSON strings to decode as bytes.
//   - A top-level `"_bstr_encoding"` key is always `"hex"`.
//   - Absent optional fields are absent in the JSON too (not null).
//
// ── skip-guard ───────────────────────────────────────────────────────────────
// The test fails hard if the output directory cannot be created.  It is
// intentional: fixture generation must succeed for the Java side to validate.
//
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_cbor_codec.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

const _codec = VhrpCborCodec();

// Path resolution: `flutter test` CWD == `client/` package root.
final _fixtureDir = Directory('../.private.local/vhrp_fixtures/c2s');

/// Writes a C2S fixture pair (.cbor + .json) for [msg].
///
/// [fileName] is the bare name without extension, e.g.
/// `session_open__no_resume`.
///
/// [expectedJson] is the expected decoded structure (field → value).
/// Fields whose wire type is CBOR `bstr` must be represented as lowercase
/// hex strings; list their dot-paths in [bstrFields].
void _writeFixture(
  String fileName,
  VhrpC2sMessage msg,
  Map<String, Object?> expectedJson, {
  List<String> bstrFields = const [],
}) {
  final cborBytes = _codec.encode(msg);

  final cborFile = File('${_fixtureDir.path}/$fileName.cbor');
  cborFile.writeAsBytesSync(cborBytes);

  final meta = <String, Object?>{
    '_bstr_encoding': 'hex',
    if (bstrFields.isNotEmpty) '_bstr_fields': bstrFields,
    ...expectedJson,
  };
  final jsonFile = File('${_fixtureDir.path}/$fileName.json');
  jsonFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(meta),
  );

  print('  wrote: $fileName.cbor (${cborBytes.length} bytes) + $fileName.json');
}

/// Hex-encodes [bytes] as a lowercase hex string (no prefix).
String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// ─────────────────────────────────────────────────────────────────────────────
// Test entry point
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    _fixtureDir.createSync(recursive: true);
    print('[c2s_fixture_gen] output dir: ${_fixtureDir.absolute.path}');
  });

  // ── session.open ───────────────────────────────────────────────────────────

  group('session.open fixtures', () {
    test(
      // Contract C2/C3/C5: token, modelId, audioTurnMode, inputAudio,
      // outputAudio, client map are all tstr/map keys; optional voice /
      // instructions / resume are absent when null.  Java side must decode
      // all these fields from the CBOR map without seeing null-node entries.
      'session_open__no_resume — basic session open, no voice/instructions/resume',
      () {
        final msg = SessionOpenMsg(
          messageId: 'open-001',
          token: 'eyJhbGciOiJFUzI1NiJ9.test.sig',
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
          client: {'platform': 'flutter', 'appVersion': '1.0.0'},
        );

        _writeFixture(
          'session_open__no_resume',
          msg,
          {
            'type': 'session.open',
            'messageId': 'open-001',
            'body': {
              'token': 'eyJhbGciOiJFUzI1NiJ9.test.sig',
              'modelId': 'voice-agent-prod',
              'instructions': '',
              'audioTurnMode': 'voice_activity',
              'inputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 24000,
                'channels': 1,
              },
              'outputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 24000,
                'channels': 1,
              },
              'client': {'platform': 'flutter', 'appVersion': '1.0.0'},
            },
          },
        );
      },
    );

    test(
      // Contract C3/C5: resume.sessionId is nested inside the body map under
      // 'resume' key.  Java must unwrap the nested CborMap and read sessionId
      // via text(resumeNode, "sessionId").  Without the resume map the server
      // would open a new session instead of rebinding the existing one.
      'session_open__with_resume — carries resume.sessionId',
      () {
        final msg = SessionOpenMsg(
          messageId: 'open-002',
          token: 'eyJhbGciOiJFUzI1NiJ9.test.sig',
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
          resume: ResumeRequest(sessionId: 'sess_abc123'),
        );

        _writeFixture(
          'session_open__with_resume',
          msg,
          {
            'type': 'session.open',
            'messageId': 'open-002',
            'body': {
              'token': 'eyJhbGciOiJFUzI1NiJ9.test.sig',
              'modelId': 'voice-agent-prod',
              'instructions': '',
              'audioTurnMode': 'voice_activity',
              'inputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 24000,
                'channels': 1,
              },
              'outputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 24000,
                'channels': 1,
              },
              'client': <String, Object?>{},
              'resume': {'sessionId': 'sess_abc123'},
            },
          },
        );
      },
    );

    test(
      // Contract C2/C6: voice and instructions are optional tstr fields.
      // Non-ASCII instructions (Japanese) must survive CBOR UTF-8 encoding
      // and be read by Java's Jackson CBOR as a valid String.
      'session_open__with_instructions — voice + Japanese instructions',
      () {
        final msg = SessionOpenMsg(
          messageId: 'open-003',
          token: 'eyJhbGciOiJFUzI1NiJ9.test.sig',
          modelId: 'voice-agent-prod',
          voice: 'alloy',
          instructions: '日本語で話してください。', // non-ASCII
          audioTurnMode: 'manual',
          inputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 16000,
            channels: 1,
          ),
          outputAudio: AudioFormat(
            encoding: 'pcm_s16le',
            sampleRate: 24000,
            channels: 1,
          ),
          client: {'platform': 'flutter', 'locale': 'ja-JP'},
        );

        _writeFixture(
          'session_open__with_instructions',
          msg,
          {
            'type': 'session.open',
            'messageId': 'open-003',
            'body': {
              'token': 'eyJhbGciOiJFUzI1NiJ9.test.sig',
              'modelId': 'voice-agent-prod',
              'voice': 'alloy',
              'instructions': '日本語で話してください。',
              'audioTurnMode': 'manual',
              'inputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 16000,
                'channels': 1,
              },
              'outputAudio': {
                'encoding': 'pcm_s16le',
                'sampleRate': 24000,
                'channels': 1,
              },
              'client': {'platform': 'flutter', 'locale': 'ja-JP'},
            },
          },
        );
      },
    );
  });

  // ── audio.turn.mode.set ────────────────────────────────────────────────────

  group('audio.turn.mode.set fixtures', () {
    test(
      // Contract C2: mode is a tstr; Java reads it via text(body, "mode").
      // A malformed encoding would cause mode=null which silently breaks
      // VAD/manual switching for the user.
      'audio_turn_mode_set__voice_activity',
      () {
        final msg = AudioTurnModeSetMsg(mode: 'voice_activity');
        _writeFixture(
          'audio_turn_mode_set__voice_activity',
          msg,
          {
            'type': 'audio.turn.mode.set',
            'body': {'mode': 'voice_activity'},
          },
        );
      },
    );

    test('audio_turn_mode_set__manual', () {
      final msg = AudioTurnModeSetMsg(mode: 'manual');
      _writeFixture(
        'audio_turn_mode_set__manual',
        msg,
        {
          'type': 'audio.turn.mode.set',
          'body': {'mode': 'manual'},
        },
      );
    });
  });

  // ── session.instructions.set ───────────────────────────────────────────────

  group('session.instructions.set fixtures', () {
    test(
      // Contract C2: instructions is a tstr when present.
      'session_instructions_set__basic',
      () {
        final msg = SessionInstructionsSetMsg(
          messageId: 'inst-001',
          instructions: 'You are a helpful assistant.',
        );
        _writeFixture(
          'session_instructions_set__basic',
          msg,
          {
            'type': 'session.instructions.set',
            'messageId': 'inst-001',
            'body': {'instructions': 'You are a helpful assistant.'},
          },
        );
      },
    );

    test(
      // Contract C5: clear is represented as an empty tstr.
      'session_instructions_set__empty_instructions',
      () {
        final msg = SessionInstructionsSetMsg(
          messageId: 'inst-002',
          instructions: '',
        );
        _writeFixture(
          'session_instructions_set__empty_instructions',
          msg,
          {
            'type': 'session.instructions.set',
            'messageId': 'inst-002',
            'body': {'instructions': ''},
            // 'instructions' is intentionally absent from body
          },
        );
      },
    );
  });

  // ── live.audio.chunk ───────────────────────────────────────────────────────

  group('live.audio.chunk fixtures', () {
    test(
      // Contract C1: pcm must be CBOR bstr so Java's isBinary() returns true.
      // If Dart encoded it as tstr/base64 the server would get an empty
      // byte[] and the user's live voice stream would be silently discarded.
      'live_audio_chunk__with_pcm — bstr payload, small sequence',
      () {
        final pcm = Uint8List.fromList(
          [0x00, 0x01, 0x80, 0xFF, 0x7F, 0xAB, 0xCD, 0xEF],
        );
        final msg = LiveAudioChunkMsg(pcm: pcm, sequence: 42);

        _writeFixture(
          'live_audio_chunk__with_pcm',
          msg,
          {
            'type': 'live.audio.chunk',
            'body': {
              'pcm': _hex(pcm),
              'sequence': 42,
            },
          },
          bstrFields: ['body.pcm'],
        );
      },
    );

    test(
      // Contract C4: sequence is a Dart int that can exceed 2^31-1 (Int.MAX).
      // Java must decode via asLong() — VhrpCborCodec.longValue() does this.
      // Using asInt() would silently truncate values > 2^31-1 to negative,
      // causing sequence ordering to break at high chunk counts.
      'live_audio_chunk__large_sequence — sequence > 2^31-1',
      () {
        final pcm = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        // 2^31 = 2147483648; use a value comfortably above Int.MAX
        const largeSeq = 2147483648; // exactly 2^31
        final msg = LiveAudioChunkMsg(pcm: pcm, sequence: largeSeq);

        _writeFixture(
          'live_audio_chunk__large_sequence',
          msg,
          {
            'type': 'live.audio.chunk',
            'body': {
              'pcm': _hex(pcm),
              'sequence': largeSeq,
            },
          },
          bstrFields: ['body.pcm'],
        );
      },
    );
  });

  // ── turn.audio.submit ──────────────────────────────────────────────────────

  group('turn.audio.submit fixtures', () {
    test(
      // Contract C1: pcm must be CBOR bstr.  A manual-mode audio turn carries
      // a larger PCM buffer than a live chunk.  The server uses isBinary() to
      // extract it; base64 text would yield an empty byte[].
      'turn_audio_submit__with_pcm — bstr payload',
      () {
        final pcm = Uint8List.fromList(
          List.generate(16, (i) => (i * 17) & 0xFF),
        );
        final msg = TurnAudioSubmitMsg(
          messageId: 'taudio-001',
          clientItemId: 'ci-audio-001',
          pcm: pcm,
          sampleRate: 24000,
          channels: 1,
          bitDepth: 16,
        );

        _writeFixture(
          'turn_audio_submit__with_pcm',
          msg,
          {
            'type': 'turn.audio.submit',
            'messageId': 'taudio-001',
            'body': {
              'clientItemId': 'ci-audio-001',
              'pcm': _hex(pcm),
              'sampleRate': 24000,
              'channels': 1,
              'bitDepth': 16,
            },
          },
          bstrFields: ['body.pcm'],
        );
      },
    );
  });

  // ── turn.text.submit ───────────────────────────────────────────────────────

  group('turn.text.submit fixtures', () {
    test(
      // Contract C2: text is a CBOR tstr.  ASCII text must round-trip exactly.
      'turn_text_submit__basic',
      () {
        final msg = TurnTextSubmitMsg(
          messageId: 'txt-001',
          clientItemId: 'ci-txt-001',
          text: 'Hello, world!',
        );

        _writeFixture(
          'turn_text_submit__basic',
          msg,
          {
            'type': 'turn.text.submit',
            'messageId': 'txt-001',
            'body': {
              'clientItemId': 'ci-txt-001',
              'text': 'Hello, world!',
            },
          },
        );
      },
    );

    test(
      // Contract C6: non-ASCII (Japanese) text is encoded as CBOR UTF-8 tstr.
      // Jackson CBOR decodes it as a Java String with full Unicode.  Any
      // encoding mismatch would garble the user's message before it reaches
      // the AI.
      'turn_text_submit__japanese — non-ASCII UTF-8 text',
      () {
        const text = 'こんにちは世界！🎙️ テスト';
        final msg = TurnTextSubmitMsg(
          messageId: 'txt-002',
          clientItemId: 'ci-txt-002',
          text: text,
        );

        _writeFixture(
          'turn_text_submit__japanese',
          msg,
          {
            'type': 'turn.text.submit',
            'messageId': 'txt-002',
            'body': {
              'clientItemId': 'ci-txt-002',
              'text': text,
            },
          },
        );
      },
    );
  });

  // ── turn.image.submit ──────────────────────────────────────────────────────

  group('turn.image.submit fixtures', () {
    test(
      // Contract C1: imageBytes must be CBOR bstr so Java's isBinary() returns
      // true.  The server sniffs MIME from the leading magic bytes; if the
      // bytes arrived as base64 text the MIME sniffer would see base64 chars
      // rather than the real magic bytes and reject the image.
      'turn_image_submit__with_jpeg — bstr with JPEG magic bytes',
      () {
        // JPEG SOI magic bytes + minimal dummy payload
        final imageBytes = Uint8List.fromList(
          [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00],
        );
        final msg = TurnImageSubmitMsg(
          messageId: 'img-001',
          clientItemId: 'ci-img-001',
          imageBytes: imageBytes,
        );

        _writeFixture(
          'turn_image_submit__with_jpeg',
          msg,
          {
            'type': 'turn.image.submit',
            'messageId': 'img-001',
            'body': {
              'clientItemId': 'ci-img-001',
              'imageBytes': _hex(imageBytes),
            },
          },
          bstrFields: ['body.imageBytes'],
        );
      },
    );
  });

  // ── tools.set ─────────────────────────────────────────────────────────────

  group('tools.set fixtures', () {
    test(
      // Contract C2/C3: tools is a CBOR array of maps.  Empty array disables
      // tools.  Java's decodeToolSpecs() iterates the array; an absent or
      // non-array value would produce an empty list silently.
      'tools_set__empty — empty tools array disables tools',
      () {
        final msg = ToolsSetMsg(messageId: 'tools-001', tools: []);

        _writeFixture(
          'tools_set__empty',
          msg,
          {
            'type': 'tools.set',
            'messageId': 'tools-001',
            'body': {'tools': <Object?>[]},
          },
        );
      },
    );

    test(
      // Contract C2/C3: multiple tools with nested JSON-Schema parameters map.
      // Java's toMap() must reconstruct the nested map correctly so the AI
      // receives accurate parameter schemas.
      'tools_set__multi_tool — two tools with nested parameters',
      () {
        final msg = ToolsSetMsg(
          messageId: 'tools-002',
          tools: [
            ToolSpec(
              name: 'get_weather',
              description: '現在の天気を取得する', // non-ASCII description
              parameters: {
                'type': 'object',
                'properties': {
                  'city': {'type': 'string', 'description': '都市名'},
                  'unit': {
                    'type': 'string',
                    'enum': ['celsius', 'fahrenheit'],
                  },
                },
                'required': ['city'],
              },
            ),
            ToolSpec(
              name: 'search_docs',
              description: 'Search internal documents',
              parameters: {
                'type': 'object',
                'properties': {
                  'query': {'type': 'string'},
                },
                'required': ['query'],
              },
            ),
          ],
        );

        _writeFixture(
          'tools_set__multi_tool',
          msg,
          {
            'type': 'tools.set',
            'messageId': 'tools-002',
            'body': {
              'tools': [
                {
                  'name': 'get_weather',
                  'description': '現在の天気を取得する',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'city': {
                        'type': 'string',
                        'description': '都市名',
                      },
                      'unit': {
                        'type': 'string',
                        'enum': ['celsius', 'fahrenheit'],
                      },
                    },
                    'required': ['city'],
                  },
                },
                {
                  'name': 'search_docs',
                  'description': 'Search internal documents',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'query': {'type': 'string'},
                    },
                    'required': ['query'],
                  },
                },
              ],
            },
          },
        );
      },
    );
    test(
      // Regression: tools with no parameters (empty properties map) must NOT
      // be encoded as the string "{}" via _dartToCbor fallback.
      // The const map {type:object, properties:{}} contains a nested const
      // _ConstMap<dynamic,dynamic> for properties; _dartToCbor must handle
      // any Map type, not just Map<String,Object?>.
      'tools_set__no_args_tool — empty properties map round-trip',
      () {
        final msg = ToolsSetMsg(
          messageId: 'tools-003',
          tools: [
            ToolSpec(
              name: 'fs_active_files',
              description:
                  'List currently active filesystem files in the runtime open set.',
              parameters: const {
                'type': 'object',
                'properties': <String, dynamic>{},
              },
            ),
          ],
        );

        _writeFixture(
          'tools_set__no_args_tool',
          msg,
          {
            'type': 'tools.set',
            'messageId': 'tools-003',
            'body': {
              'tools': [
                {
                  'name': 'fs_active_files',
                  'description':
                      'List currently active filesystem files in the runtime open set.',
                  'parameters': {
                    'type': 'object',
                    'properties': <String, Object?>{},
                  },
                },
              ],
            },
          },
        );
      },
    );
  });

  // ── session.extension.apply ────────────────────────────────────────────────

  group('session.extension.apply fixtures', () {
    test(
      // Contract C2/C3: extensionType is tstr; payload is a nested map.
      // Java's toMap() must preserve the payload structure so provider
      // extensions work correctly.
      'session_extension_apply__basic',
      () {
        final msg = SessionExtensionApplyMsg(
          messageId: 'ext-001',
          extensionType: 'session.reasoning_effort_selection',
          payload: {
            'effort': 'medium',
            'maxTokens': 2000,
          },
        );

        _writeFixture(
          'session_extension_apply__basic',
          msg,
          {
            'type': 'session.extension.apply',
            'messageId': 'ext-001',
            'body': {
              'extensionType': 'session.reasoning_effort_selection',
              'payload': {
                'effort': 'medium',
                'maxTokens': 2000,
              },
            },
          },
        );
      },
    );
  });

  // ── tool.result.submit ─────────────────────────────────────────────────────

  group('tool.result.submit fixtures', () {
    test(
      // Contract C2: callId, output, disposition are tstr.  A success result
      // must have errorMessage absent (not CBOR null) per contract C5.
      'tool_result_submit__success — no errorMessage',
      () {
        final msg = ToolResultSubmitMsg(
          messageId: 'res-001',
          clientItemId: 'ci-res-001',
          callId: 'call_xyz789',
          output: '{"temperature":22,"unit":"celsius"}',
          disposition: 'success',
          errorMessage: null,
        );

        _writeFixture(
          'tool_result_submit__success',
          msg,
          {
            'type': 'tool.result.submit',
            'messageId': 'res-001',
            'body': {
              'clientItemId': 'ci-res-001',
              'callId': 'call_xyz789',
              'output': '{"temperature":22,"unit":"celsius"}',
              'disposition': 'success',
              // errorMessage absent
            },
          },
        );
      },
    );

    test(
      // Contract C2/C5: when disposition is 'error', errorMessage is a
      // non-null tstr.  Java reads it via text(body, "errorMessage") which
      // returns null for absent keys too.  The fixture proves the key is
      // present and textual when provided.
      'tool_result_submit__error — with errorMessage',
      () {
        final msg = ToolResultSubmitMsg(
          messageId: 'res-002',
          clientItemId: 'ci-res-002',
          callId: 'call_abc123',
          output: '',
          disposition: 'error',
          errorMessage: 'Network timeout when fetching weather data',
        );

        _writeFixture(
          'tool_result_submit__error',
          msg,
          {
            'type': 'tool.result.submit',
            'messageId': 'res-002',
            'body': {
              'clientItemId': 'ci-res-002',
              'callId': 'call_abc123',
              'output': '',
              'disposition': 'error',
              'errorMessage': 'Network timeout when fetching weather data',
            },
          },
        );
      },
    );
  });

  // ── assistant.interrupt ────────────────────────────────────────────────────

  group('assistant.interrupt fixtures', () {
    test(
      // Contract C2: reason is tstr; messageId is absent (one-way message,
      // contract C5).  Java reads reason via text(body, "reason"); missing
      // messageId is fine because Java only reads root.get("messageId").
      'assistant_interrupt__barge_in',
      () {
        final msg = AssistantInterruptMsg(reason: 'barge_in');

        _writeFixture(
          'assistant_interrupt__barge_in',
          msg,
          {
            'type': 'assistant.interrupt',
            'body': {'reason': 'barge_in'},
          },
        );
      },
    );
  });

  // ── thread.sync.request ────────────────────────────────────────────────────

  group('thread.sync.request fixtures', () {
    test(
      // Contract C2: reason is tstr; advisory only.  Java reads it via
      // text(body, "reason").  No sequence or cursor — the reply is always a
      // full snapshot.
      'thread_sync_request__basic',
      () {
        final msg = ThreadSyncRequestMsg(
          messageId: 'sync-001',
          reason: 'reconnect',
        );

        _writeFixture(
          'thread_sync_request__basic',
          msg,
          {
            'type': 'thread.sync.request',
            'messageId': 'sync-001',
            'body': {'reason': 'reconnect'},
          },
        );
      },
    );
  });
}
