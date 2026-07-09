// VHRP/1 typed message set for the Dart client.
//
// Each class mirrors the wire contract defined in
// `client/docs/hosted_realtime/02_vhrp_wire_protocol.md` and the server
// canonical record set in `VhrpMessage.java`.  The split into [VhrpC2sMessage]
// and [VhrpS2cMessage] follows the Java `C2S` / `S2C` marker interfaces so the
// codec can be direction-aware at the type level.
//
// Binary payloads (PCM, image bytes) are [Uint8List] — never base64 strings —
// because CBOR carries them as `bstr`.  Base64 only appears when values are
// projected into `RealtimeThreadAudioPart.audioChunks`, which is the thread
// projector's responsibility (next step), not this layer's.

import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-structures
// ─────────────────────────────────────────────────────────────────────────────

/// `session.open.body.resume`: present only when reconnecting.
/// Matches `VhrpMessage.ResumeRequest`.
final class ResumeRequest {
  final String sessionId;

  ResumeRequest({required this.sessionId});
}

/// One entry of `tools.set.body.tools`.
/// [parameters] is a JSON-Schema-shaped map.
/// Matches `VhrpMessage.ToolSpec`.
final class ToolSpec {
  final String name;
  final String description;
  final Map<String, Object?> parameters;

  ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// C2S — Client to Server
// ─────────────────────────────────────────────────────────────────────────────

/// Marker supertype for all client-to-server messages.
sealed class VhrpC2sMessage {
  /// The wire `type` discriminator, e.g. `"session.open"`.
  String get type;
}

/// `session.open`: bootstraps (or resumes) a session.
/// [token] is the sole application-level credential (JWT).
/// [speedDialId] is the server-owned Speed Dial authority for fresh opens.
/// [resume] is present only on reconnect.
final class SessionOpenMsg extends VhrpC2sMessage {
  @override
  String get type => 'session.open';

  final String messageId;
  final String token;
  final String speedDialId;
  final String audioTurnMode;
  final ResumeRequest? resume;
  final Map<String, Object?> client;

  SessionOpenMsg({
    required this.messageId,
    required this.token,
    required this.speedDialId,
    required this.audioTurnMode,
    this.resume,
    required this.client,
  });
}

/// `audio.turn.mode.set`: switches between `voice_activity` and `manual`.
/// One-way; no messageId.
final class AudioTurnModeSetMsg extends VhrpC2sMessage {
  @override
  String get type => 'audio.turn.mode.set';

  /// Either `"voice_activity"` or `"manual"`.
  final String mode;

  AudioTurnModeSetMsg({required this.mode});
}

/// `session.instructions.set`: mid-session instructions update.
/// The empty string is the canonical clear/no-instructions value.
final class SessionInstructionsSetMsg extends VhrpC2sMessage {
  @override
  String get type => 'session.instructions.set';

  final String messageId;
  final String instructions;

  SessionInstructionsSetMsg({
    required this.messageId,
    required this.instructions,
  });
}

/// `live.audio.chunk`: one live mic PCM chunk (voice_activity mode only).
/// [pcm] is a CBOR `bstr` — raw bytes, no base64.
/// One-way; no messageId.
final class LiveAudioChunkMsg extends VhrpC2sMessage {
  @override
  String get type => 'live.audio.chunk';

  final Uint8List pcm;
  final int sequence;

  LiveAudioChunkMsg({required this.pcm, required this.sequence});
}

/// `turn.audio.submit`: one completed manual audio turn.
/// [pcm] is a CBOR `bstr`.
final class TurnAudioSubmitMsg extends VhrpC2sMessage {
  @override
  String get type => 'turn.audio.submit';

  final String messageId;
  final String clientItemId;
  final Uint8List pcm;
  final int sampleRate;
  final int channels;
  final int bitDepth;

  TurnAudioSubmitMsg({
    required this.messageId,
    required this.clientItemId,
    required this.pcm,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
  });
}

/// `turn.text.submit`: one user text turn.
final class TurnTextSubmitMsg extends VhrpC2sMessage {
  @override
  String get type => 'turn.text.submit';

  final String messageId;
  final String clientItemId;
  final String text;

  TurnTextSubmitMsg({
    required this.messageId,
    required this.clientItemId,
    required this.text,
  });
}

/// `turn.image.submit`: one user image turn.
/// [imageBytes] is a CBOR `bstr`.  MIME sniffed server-side.
final class TurnImageSubmitMsg extends VhrpC2sMessage {
  @override
  String get type => 'turn.image.submit';

  final String messageId;
  final String clientItemId;
  final Uint8List imageBytes;

  TurnImageSubmitMsg({
    required this.messageId,
    required this.clientItemId,
    required this.imageBytes,
  });
}

/// `tools.set`: replaces the session tool catalog.
/// Empty list disables tools.
final class ToolsSetMsg extends VhrpC2sMessage {
  @override
  String get type => 'tools.set';

  final String messageId;
  final List<ToolSpec> tools;

  ToolsSetMsg({required this.messageId, required this.tools});
}

/// `session.extension.apply`: opaque provider-extension update.
final class SessionExtensionApplyMsg extends VhrpC2sMessage {
  @override
  String get type => 'session.extension.apply';

  final String messageId;
  final String extensionType;
  final Map<String, Object?> payload;

  SessionExtensionApplyMsg({
    required this.messageId,
    required this.extensionType,
    required this.payload,
  });
}

/// `tool.result.submit`: result of a tool call keyed by [callId].
/// [output] is an opaque UTF-8 string (not necessarily JSON).
final class ToolResultSubmitMsg extends VhrpC2sMessage {
  @override
  String get type => 'tool.result.submit';

  final String messageId;
  final String clientItemId;
  final String callId;
  final String output;
  final String disposition;
  final String? errorMessage;

  ToolResultSubmitMsg({
    required this.messageId,
    required this.clientItemId,
    required this.callId,
    required this.output,
    required this.disposition,
    this.errorMessage,
  });
}

/// `assistant.interrupt`: stop the current generation.
/// One-way; no messageId.
final class AssistantInterruptMsg extends VhrpC2sMessage {
  @override
  String get type => 'assistant.interrupt';

  final String reason;

  AssistantInterruptMsg({required this.reason});
}

/// `session.end`: explicitly terminates this hosted realtime session.
/// One-way terminal command; no messageId and no ack.
final class SessionEndMsg extends VhrpC2sMessage {
  @override
  String get type => 'session.end';
}

/// `thread.sync.request`: asks for a fresh full `thread.snapshot`.
/// No cursor or revision — the reply is always a full snapshot.
/// [reason] is advisory only.
final class ThreadSyncRequestMsg extends VhrpC2sMessage {
  @override
  String get type => 'thread.sync.request';

  final String messageId;
  final String reason;

  ThreadSyncRequestMsg({required this.messageId, required this.reason});
}

// ─────────────────────────────────────────────────────────────────────────────
// S2C — Server to Client
// ─────────────────────────────────────────────────────────────────────────────

/// Marker supertype for all server-to-client messages.
sealed class VhrpS2cMessage {
  /// The wire `type` discriminator.
  String get type;
}

/// `session.ready`: reply to a new `session.open`.
/// [capabilityExtensions] lists extension keys this session supports.
final class SessionReadyMsg extends VhrpS2cMessage {
  @override
  String get type => 'session.ready';

  final String? replyTo;
  final String sessionId;
  final String threadId;
  final String? conversationId;
  final List<String> capabilityExtensions;

  SessionReadyMsg({
    this.replyTo,
    required this.sessionId,
    required this.threadId,
    this.conversationId,
    required this.capabilityExtensions,
  });
}

/// `session.resumed`: reply to a resume `session.open`.
/// The client must then send `thread.sync.request` to get the full state.
final class SessionResumedMsg extends VhrpS2cMessage {
  @override
  String get type => 'session.resumed';

  final String? replyTo;
  final String sessionId;
  final String threadId;
  final String? conversationId;

  SessionResumedMsg({
    this.replyTo,
    required this.sessionId,
    required this.threadId,
    this.conversationId,
  });
}

/// `ack`: generic success reply correlated by [replyTo].
final class AckMsg extends VhrpS2cMessage {
  @override
  String get type => 'ack';

  final String? replyTo;
  final bool accepted;
  final String? clientItemId;
  final bool applied;

  AckMsg({
    this.replyTo,
    required this.accepted,
    this.clientItemId,
    required this.applied,
  });
}

/// `thread.snapshot`: authoritative full thread state.
/// [items] are opaque maps — the thread projector interprets their shape.
final class ThreadSnapshotMsg extends VhrpS2cMessage {
  @override
  String get type => 'thread.snapshot';

  final String threadId;
  final String? conversationId;

  /// Each element matches the shape of a `RealtimeThreadItem` as defined in
  /// `02_vhrp_wire_protocol.md`.  Kept opaque here; the thread projector owns
  /// the mapping to `RealtimeThread`.
  final List<Map<String, Object?>> items;

  ThreadSnapshotMsg({
    required this.threadId,
    this.conversationId,
    required this.items,
  });
}

/// `thread.patch`: a live op list applied to the client's projected thread.
/// Fire-and-forget; no revision or sequence.
final class ThreadPatchMsg extends VhrpS2cMessage {
  @override
  String get type => 'thread.patch';

  final List<ThreadPatchOp> ops;

  ThreadPatchMsg({required this.ops});
}

/// `assistant.audio.chunk`: one assistant PCM chunk.
/// [pcm] arrives as CBOR `bstr` and is surfaced as raw [Uint8List].
/// No base64 decode needed — this is the key wire contract.
final class AssistantAudioChunkMsg extends VhrpS2cMessage {
  @override
  String get type => 'assistant.audio.chunk';

  final String itemId;
  final int contentIndex;
  final Uint8List pcm;

  AssistantAudioChunkMsg({
    required this.itemId,
    required this.contentIndex,
    required this.pcm,
  });
}

/// `assistant.audio.done`: assistant audio boundary notification.
/// Distinct from item completion; triggers `assistantAudioCompleted`.
final class AssistantAudioDoneMsg extends VhrpS2cMessage {
  @override
  String get type => 'assistant.audio.done';

  final String itemId;
  final int contentIndex;

  AssistantAudioDoneMsg({required this.itemId, required this.contentIndex});
}

/// `vad.state`: server-side VAD speaking state.
final class VadStateMsg extends VhrpS2cMessage {
  @override
  String get type => 'vad.state';

  final bool isSpeaking;

  VadStateMsg({required this.isSpeaking});
}

/// `error`: application error frame.
/// If [recoverable] is `false`, the server closes the connection immediately.
final class ErrorMsg extends VhrpS2cMessage {
  @override
  String get type => 'error';

  final String? replyTo;
  final String code;
  final String message;
  final bool recoverable;

  ErrorMsg({
    this.replyTo,
    required this.code,
    required this.message,
    required this.recoverable,
  });
}

/// Received a `type` the client does not recognise.
///
/// Normal CBOR decode rejects unknown S2C types before this reaches the
/// adapter. This type remains as an explicit sentinel for tests or manually
/// constructed messages so unsupported protocol messages are never silent.
final class UnknownTypeS2cMsg extends VhrpS2cMessage {
  @override
  String get type => unknownType;

  final String unknownType;
  final Map<String, Object?> rawEnvelope;

  UnknownTypeS2cMsg({required this.unknownType, required this.rawEnvelope});
}

// ─────────────────────────────────────────────────────────────────────────────
// thread.patch operation types
// ─────────────────────────────────────────────────────────────────────────────

/// One operation inside a `thread.patch.body.ops` array.
/// All concrete subclasses are `final` to guard wire contract stability.
sealed class ThreadPatchOp {
  /// The wire `op` discriminator.
  String get op;
}

/// `add_item`: adds a new item to the thread.
/// If [item.id] already exists locally, treat as merge (idempotency rule).
final class AddItemOp extends ThreadPatchOp {
  @override
  String get op => 'add_item';

  final Map<String, Object?> item;
  final String? previousItemId;

  AddItemOp({required this.item, this.previousItemId});
}

/// `remove_item`: removes an item by [itemId].
final class RemoveItemOp extends ThreadPatchOp {
  @override
  String get op => 'remove_item';

  final String itemId;

  RemoveItemOp({required this.itemId});
}

/// `set_status`: updates an item's status field.
final class SetStatusOp extends ThreadPatchOp {
  @override
  String get op => 'set_status';

  final String itemId;
  final String status;

  SetStatusOp({required this.itemId, required this.status});
}

/// `set_role`: updates an item's role field.
final class SetRoleOp extends ThreadPatchOp {
  @override
  String get op => 'set_role';

  final String itemId;
  final String role;

  SetRoleOp({required this.itemId, required this.role});
}

/// `set_field`: sets one of the named scalar fields on an item.
/// [field] is one of `callId`, `name`, `arguments`, `output`,
/// `toolOutputDisposition`, `toolErrorMessage`.
final class SetFieldOp extends ThreadPatchOp {
  @override
  String get op => 'set_field';

  final String itemId;
  final String field;
  final Object? value;

  SetFieldOp({required this.itemId, required this.field, required this.value});
}

/// `put_part`: upserts a content part at [contentIndex].
/// [part] is an opaque map shaped like `{ "type": "text"|"audio"|"image", ... }`.
final class PutPartOp extends ThreadPatchOp {
  @override
  String get op => 'put_part';

  final String itemId;
  final int contentIndex;
  final Map<String, Object?> part;

  PutPartOp({
    required this.itemId,
    required this.contentIndex,
    required this.part,
  });
}

/// `append_text`: appends [delta] to a text part.
final class AppendTextOp extends ThreadPatchOp {
  @override
  String get op => 'append_text';

  final String itemId;
  final int contentIndex;
  final String delta;

  AppendTextOp({
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

/// `replace_text`: replaces the full text of a text part.
final class ReplaceTextOp extends ThreadPatchOp {
  @override
  String get op => 'replace_text';

  final String itemId;
  final int contentIndex;
  final String text;

  ReplaceTextOp({
    required this.itemId,
    required this.contentIndex,
    required this.text,
  });
}

/// `append_transcript`: appends [delta] to the transcript of an audio part.
final class AppendTranscriptOp extends ThreadPatchOp {
  @override
  String get op => 'append_transcript';

  final String itemId;
  final int contentIndex;
  final String delta;

  AppendTranscriptOp({
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

/// `replace_transcript`: replaces the full transcript of an audio part.
final class ReplaceTranscriptOp extends ThreadPatchOp {
  @override
  String get op => 'replace_transcript';

  final String itemId;
  final int contentIndex;
  final String text;

  ReplaceTranscriptOp({
    required this.itemId,
    required this.contentIndex,
    required this.text,
  });
}

/// `set_conversation_id`: updates the thread's conversationId.
final class SetConversationIdOp extends ThreadPatchOp {
  @override
  String get op => 'set_conversation_id';

  final String conversationId;

  SetConversationIdOp({required this.conversationId});
}

/// Received an `op` value the client does not recognise.
/// The adapter should treat this as a desync trigger and send
/// `thread.sync.request`.
final class UnknownOp extends ThreadPatchOp {
  @override
  String get op => unknownOp;

  final String unknownOp;
  final Map<String, Object?> rawOp;

  UnknownOp({required this.unknownOp, required this.rawOp});
}
