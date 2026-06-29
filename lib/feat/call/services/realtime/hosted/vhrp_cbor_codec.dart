// VHRP/1 CBOR codec for the Dart client.
//
// Responsibilities
// ────────────────
// • Encode [VhrpC2sMessage]  → [Uint8List]  (outbound binary frame)
// • Decode [Uint8List]       → [VhrpS2cMessage] (inbound binary frame)
//
// This codec is the only layer that touches raw CBOR.  Everything above it
// works with typed [VhrpC2sMessage] / [VhrpS2cMessage] objects.
//
// Key wire contracts preserved here:
// 1. Binary payloads (PCM, image bytes) are CBOR `bstr` — never base64.
// 2. Text strings are CBOR `tstr`.
// 3. Each WebSocket message is exactly one top-level CBOR map.
// 4. Unknown S2C `type` is a protocol error and fails decode.
// 5. Unknown `thread.patch` `op` → [UnknownOp] inside [ThreadPatchMsg].
//
// The `cbor` package (^6.5.1) is used for encode/decode.
// CborBytes  = CBOR major type 2 = byte string (`bstr`)
// CborString = CBOR major type 3 = text string (`tstr`)

import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import 'vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// VHRP/1 CBOR codec — encode C2S messages and decode S2C messages.
///
/// This class is stateless and safe to share across isolates / connections.
class VhrpCborCodec {
  const VhrpCborCodec();

  // ── Encode ────────────────────────────────────────────────────────────────

  /// Serialises [message] into a CBOR binary frame ready to send over
  /// the WebSocket as a binary message.
  Uint8List encode(VhrpC2sMessage message) {
    final root = CborMap({});
    _putText(root, 'type', message.type);

    switch (message) {
      case SessionOpenMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'token', m.token);
        _putText(body, 'speedDialId', m.speedDialId);
        _putText(body, 'audioTurnMode', m.audioTurnMode);
        if (m.resume != null) {
          body[CborString('resume')] = CborMap({
            CborString('sessionId'): CborString(m.resume!.sessionId),
          });
        }
        body[CborString('client')] = _mapToCbor(m.client);
        root[CborString('body')] = body;

      case AudioTurnModeSetMsg m:
        final body = CborMap({});
        _putText(body, 'mode', m.mode);
        root[CborString('body')] = body;

      case SessionInstructionsSetMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'instructions', m.instructions);
        root[CborString('body')] = body;

      case LiveAudioChunkMsg m:
        final body = CborMap({});
        body[CborString('pcm')] = CborBytes(m.pcm);
        body[CborString('sequence')] = CborSmallInt(m.sequence);
        root[CborString('body')] = body;

      case TurnAudioSubmitMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'clientItemId', m.clientItemId);
        body[CborString('pcm')] = CborBytes(m.pcm);
        body[CborString('sampleRate')] = CborSmallInt(m.sampleRate);
        body[CborString('channels')] = CborSmallInt(m.channels);
        body[CborString('bitDepth')] = CborSmallInt(m.bitDepth);
        root[CborString('body')] = body;

      case TurnTextSubmitMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'clientItemId', m.clientItemId);
        _putText(body, 'text', m.text);
        root[CborString('body')] = body;

      case TurnImageSubmitMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'clientItemId', m.clientItemId);
        body[CborString('imageBytes')] = CborBytes(m.imageBytes);
        root[CborString('body')] = body;

      case ToolsSetMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        body[CborString('tools')] = CborList(
          m.tools.map(_encodeToolSpec).toList(),
        );
        root[CborString('body')] = body;

      case SessionExtensionApplyMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'extensionType', m.extensionType);
        body[CborString('payload')] = _mapToCbor(m.payload);
        root[CborString('body')] = body;

      case ToolResultSubmitMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'clientItemId', m.clientItemId);
        _putText(body, 'callId', m.callId);
        _putText(body, 'output', m.output);
        _putText(body, 'disposition', m.disposition);
        _putTextNullable(body, 'errorMessage', m.errorMessage);
        root[CborString('body')] = body;

      case AssistantInterruptMsg m:
        final body = CborMap({});
        _putText(body, 'reason', m.reason);
        root[CborString('body')] = body;

      case SessionEndMsg _:
        root[CborString('body')] = CborMap({});

      case ThreadSyncRequestMsg m:
        _putText(root, 'messageId', m.messageId);
        final body = CborMap({});
        _putText(body, 'reason', m.reason);
        root[CborString('body')] = body;
    }

    return Uint8List.fromList(cbor.encode(root));
  }

  // ── Decode ────────────────────────────────────────────────────────────────

  /// Deserialises one inbound binary [frame] into a typed [VhrpS2cMessage].
  ///
  /// Throws [VhrpCborDecodeException] if the frame is not a valid CBOR map,
  /// if mandatory `type` / `body` fields are absent, or if the S2C `type` is
  /// not implemented by this client. Treating unknown types as decode failures
  /// prevents implemented protocol messages from being silently stubbed out.
  VhrpS2cMessage decode(Uint8List frame) {
    final CborValue decoded;
    try {
      decoded = cbor.decode(frame);
    } catch (e) {
      throw VhrpCborDecodeException('Frame is not valid CBOR', cause: e);
    }

    if (decoded is! CborMap) {
      throw VhrpCborDecodeException(
        'VHRP frame must be a CBOR map, got ${decoded.runtimeType}',
      );
    }

    final root = decoded;
    final typeVal = root[CborString('type')];
    if (typeVal is! CborString) {
      throw VhrpCborDecodeException(
        "VHRP envelope is missing a text 'type' field",
      );
    }
    final type = typeVal.toString();

    final bodyVal = root[CborString('body')];
    if (bodyVal is! CborMap) {
      throw VhrpCborDecodeException(
        "VHRP envelope is missing a map 'body' field",
      );
    }

    final replyTo = _getText(root, 'replyTo');

    return switch (type) {
      'session.ready' => _decodeSessionReady(replyTo, bodyVal),
      'session.resumed' => _decodeSessionResumed(replyTo, bodyVal),
      'ack' => _decodeAck(replyTo, bodyVal),
      'thread.snapshot' => _decodeThreadSnapshot(bodyVal),
      'thread.patch' => _decodeThreadPatch(bodyVal),
      'assistant.audio.chunk' => _decodeAssistantAudioChunk(bodyVal),
      'assistant.audio.done' => _decodeAssistantAudioDone(bodyVal),
      'vad.state' => _decodeVadState(bodyVal),
      'error' => _decodeError(replyTo, bodyVal),
      _ => throw VhrpCborDecodeException(
        "Unsupported VHRP S2C message type '$type'",
      ),
    };
  }

  // ── Decode helpers ────────────────────────────────────────────────────────

  SessionReadyMsg _decodeSessionReady(String? replyTo, CborMap body) {
    final caps = body[CborString('capabilities')];
    final extensions = <String>[];
    if (caps is CborMap) {
      final extVal = caps[CborString('extensions')];
      if (extVal is CborList) {
        for (final e in extVal) {
          if (e is CborString) extensions.add(e.toString());
        }
      }
    }
    return SessionReadyMsg(
      replyTo: replyTo,
      sessionId: _requireText(body, 'sessionId'),
      threadId: _requireText(body, 'threadId'),
      conversationId: _getText(body, 'conversationId'),
      capabilityExtensions: extensions,
    );
  }

  SessionResumedMsg _decodeSessionResumed(String? replyTo, CborMap body) =>
      SessionResumedMsg(
        replyTo: replyTo,
        sessionId: _requireText(body, 'sessionId'),
        threadId: _requireText(body, 'threadId'),
        conversationId: _getText(body, 'conversationId'),
      );

  AckMsg _decodeAck(String? replyTo, CborMap body) => AckMsg(
    replyTo: replyTo,
    accepted: _getBool(body, 'accepted') ?? false,
    clientItemId: _getText(body, 'clientItemId'),
    applied: _getBool(body, 'applied') ?? false,
  );

  ThreadSnapshotMsg _decodeThreadSnapshot(CborMap body) {
    final itemsVal = body[CborString('items')];
    final items = <Map<String, Object?>>[];
    if (itemsVal is CborList) {
      for (final e in itemsVal) {
        if (e is CborMap) items.add(_cborMapTodart(e));
      }
    }
    return ThreadSnapshotMsg(
      threadId: _requireText(body, 'threadId'),
      conversationId: _getText(body, 'conversationId'),
      items: items,
    );
  }

  ThreadPatchMsg _decodeThreadPatch(CborMap body) {
    final opsVal = body[CborString('ops')];
    final ops = <ThreadPatchOp>[];
    if (opsVal is CborList) {
      for (final e in opsVal) {
        if (e is CborMap) ops.add(_decodeOp(e));
      }
    }
    return ThreadPatchMsg(ops: ops);
  }

  ThreadPatchOp _decodeOp(CborMap raw) {
    final opVal = _getText(raw, 'op');
    if (opVal == null) {
      return UnknownOp(unknownOp: '<missing>', rawOp: _cborMapTodart(raw));
    }
    return switch (opVal) {
      'add_item' => AddItemOp(
        item: _cborMapTodart(
          raw[CborString('item')] is CborMap
              ? raw[CborString('item')] as CborMap
              : CborMap({}),
        ),
      ),
      'remove_item' => RemoveItemOp(itemId: _requireTextMap(raw, 'itemId')),
      'set_status' => SetStatusOp(
        itemId: _requireTextMap(raw, 'itemId'),
        status: _requireTextMap(raw, 'status'),
      ),
      'set_role' => SetRoleOp(
        itemId: _requireTextMap(raw, 'itemId'),
        role: _requireTextMap(raw, 'role'),
      ),
      'set_field' => SetFieldOp(
        itemId: _requireTextMap(raw, 'itemId'),
        field: _requireTextMap(raw, 'field'),
        value: _cborValueTodart(raw[CborString('value')]),
      ),
      'put_part' => PutPartOp(
        itemId: _requireTextMap(raw, 'itemId'),
        contentIndex: _getInt(raw, 'contentIndex') ?? 0,
        part: _cborMapTodart(
          raw[CborString('part')] is CborMap
              ? raw[CborString('part')] as CborMap
              : CborMap({}),
        ),
      ),
      'append_text' => AppendTextOp(
        itemId: _requireTextMap(raw, 'itemId'),
        contentIndex: _getInt(raw, 'contentIndex') ?? 0,
        delta: _requireTextMap(raw, 'delta'),
      ),
      'replace_text' => ReplaceTextOp(
        itemId: _requireTextMap(raw, 'itemId'),
        contentIndex: _getInt(raw, 'contentIndex') ?? 0,
        text: _requireTextMap(raw, 'text'),
      ),
      'append_transcript' => AppendTranscriptOp(
        itemId: _requireTextMap(raw, 'itemId'),
        contentIndex: _getInt(raw, 'contentIndex') ?? 0,
        delta: _requireTextMap(raw, 'delta'),
      ),
      'replace_transcript' => ReplaceTranscriptOp(
        itemId: _requireTextMap(raw, 'itemId'),
        contentIndex: _getInt(raw, 'contentIndex') ?? 0,
        text: _requireTextMap(raw, 'text'),
      ),
      'set_conversation_id' => SetConversationIdOp(
        conversationId: _requireTextMap(raw, 'conversationId'),
      ),
      _ => UnknownOp(unknownOp: opVal, rawOp: _cborMapTodart(raw)),
    };
  }

  AssistantAudioChunkMsg _decodeAssistantAudioChunk(CborMap body) {
    final pcmVal = body[CborString('pcm')];
    final pcm = pcmVal is CborBytes
        ? Uint8List.fromList(pcmVal.bytes)
        : Uint8List(0);
    return AssistantAudioChunkMsg(
      itemId: _requireText(body, 'itemId'),
      contentIndex: _getInt(body, 'contentIndex') ?? 0,
      pcm: pcm,
    );
  }

  AssistantAudioDoneMsg _decodeAssistantAudioDone(CborMap body) =>
      AssistantAudioDoneMsg(
        itemId: _requireText(body, 'itemId'),
        contentIndex: _getInt(body, 'contentIndex') ?? 0,
      );

  VadStateMsg _decodeVadState(CborMap body) =>
      VadStateMsg(isSpeaking: _getBool(body, 'isSpeaking') ?? false);

  ErrorMsg _decodeError(String? replyTo, CborMap body) => ErrorMsg(
    replyTo: replyTo,
    code: _requireText(body, 'code'),
    message: _requireText(body, 'message'),
    recoverable: _getBool(body, 'recoverable') ?? true,
  );

  // ── Encode helpers ────────────────────────────────────────────────────────

  CborMap _encodeToolSpec(ToolSpec spec) => CborMap({
    CborString('name'): CborString(spec.name),
    CborString('description'): CborString(spec.description),
    CborString('parameters'): _mapToCbor(spec.parameters),
  });

  // ── CBOR ↔ Dart map conversion ─────────────────────────────────────────

  /// Converts any Dart [Map] to a [CborMap], stringifying non-String keys.
  /// Supports nested maps of any type parameter, including const maps such
  /// as [_ConstMap<dynamic,dynamic>], lists, strings, ints, doubles, bools,
  /// null, and [Uint8List] (→ CborBytes).
  CborMap _mapToCbor(Map<dynamic, dynamic> map) {
    final result = CborMap({});
    for (final entry in map.entries) {
      final key = entry.key is String
          ? entry.key as String
          : entry.key.toString();
      result[CborString(key)] = _dartToCbor(entry.value);
    }
    return result;
  }

  CborValue _dartToCbor(Object? value) {
    if (value is Map) {
      // Handles Map<String,Object?>, Map<dynamic,dynamic>, const maps, etc.
      return _mapToCbor(value);
    }
    if (value is List) {
      return CborList(value.map(_dartToCbor).toList());
    }
    return switch (value) {
      null => const CborNull(),
      bool v => CborBool(v),
      int v => CborSmallInt(v),
      double v => CborFloat(v),
      String v => CborString(v),
      Uint8List v => CborBytes(v),
      List<int> v => CborBytes(Uint8List.fromList(v)),
      _ => CborString(value.toString()),
    };
  }

  /// Converts a [CborMap] back to a Dart `Map<String, Object?>`.
  Map<String, Object?> _cborMapTodart(CborMap map) {
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      final key = entry.key;
      if (key is CborString) {
        result[key.toString()] = _cborValueTodart(entry.value);
      }
    }
    return result;
  }

  Object? _cborValueTodart(CborValue? value) {
    return switch (value) {
      null => null,
      CborNull() => null,
      CborBool v => v.value,
      CborInt v => v.toInt(),
      CborFloat v => v.value,
      CborString v => v.toString(),
      CborBytes v => Uint8List.fromList(v.bytes),
      CborMap v => _cborMapTodart(v),
      CborList v => v.map(_cborValueTodart).toList(),
      _ => null,
    };
  }

  // ── Field accessors ───────────────────────────────────────────────────────

  static void _putText(CborMap map, String key, String value) {
    map[CborString(key)] = CborString(value);
  }

  static void _putTextNullable(CborMap map, String key, String? value) {
    if (value != null) map[CborString(key)] = CborString(value);
  }

  static String? _getText(CborMap map, String key) {
    final v = map[CborString(key)];
    return v is CborString ? v.toString() : null;
  }

  static String _requireText(CborMap map, String key) {
    final v = _getText(map, key);
    if (v == null) {
      throw VhrpCborDecodeException("Missing required text field '$key'");
    }
    return v;
  }

  /// [_requireText] variant with a pre-looked-up [CborMap] reference for ops.
  static String _requireTextMap(CborMap map, String key) =>
      _requireText(map, key);

  static bool? _getBool(CborMap map, String key) {
    final v = map[CborString(key)];
    return v is CborBool ? v.value : null;
  }

  static int? _getInt(CborMap map, String key) {
    final v = map[CborString(key)];
    return v is CborInt ? v.toInt() : null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception type
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when an inbound CBOR frame cannot be parsed into a valid VHRP
/// envelope (missing mandatory fields, wrong top-level type, etc.).
///
/// Unknown S2C `type` values fail decode immediately. Unknown `thread.patch`
/// `op` values still surface as [UnknownOp] so the adapter can trigger
/// sync-request recovery for a malformed live patch without masking the frame.
class VhrpCborDecodeException implements Exception {
  final String message;
  final Object? cause;

  const VhrpCborDecodeException(this.message, {this.cause});

  @override
  String toString() => cause != null
      ? 'VhrpCborDecodeException: $message (cause: $cause)'
      : 'VhrpCborDecodeException: $message';
}
