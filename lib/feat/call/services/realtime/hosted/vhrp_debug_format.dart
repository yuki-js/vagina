// Human-readable debug formatting for VHRP/1 messages.
//
// Responsibilities:
//   • Produce a short, readable string from a typed VHRP message object for
//     logging purposes.
//   • Replace any byte-string fields (PCM, image bytes) with a
//     `<bytes: N>` summary — the raw bytes are NEVER included in the output,
//     not even as base64.
//   • Truncate large String values to [maxStringLength] characters.
//   • Recursively sanitise nested Map<String, Object?> values (e.g. the
//     `item` map in AddItemOp, the `part` map in PutPartOp) so that byte
//     strings buried deep in opaque maps are also replaced by summaries.
//
// Usage:
//   VhrpDebugFormat.formatC2s(msg)  → String (for tx logging)
//   VhrpDebugFormat.formatS2c(msg)  → String (for rx logging)
//
// This file has NO production side-effects: callers must guard invocations
// with `kDebugMode` so the format strings are never constructed in release
// builds.  The formatter itself does not import flutter/foundation.

import 'dart:typed_data';

import 'vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Formatter for VHRP/1 typed message objects.
///
/// All methods return a concise, human-readable diagnostic string.
/// Byte-string fields (PCM audio, image bytes) are replaced by
/// `<bytes: N>` summaries.  Large strings are truncated at [maxStringLength].
///
/// **Never** call these methods in production code paths — guard with
/// `kDebugMode` at the call site.
abstract final class VhrpDebugFormat {
  /// Maximum length for non-transcript operational strings before truncation.
  ///
  /// Transcript/text fields are intentionally not truncated: this diagnostic is
  /// used to inspect exact user/assistant text projection. Audio/image bytes are
  /// summarised structurally instead of string-truncated.
  static const int maxOperationalStringLength = 200;

  // ── C2S ───────────────────────────────────────────────────────────────────

  /// Formats a client-to-server [message] as a readable diagnostic string.
  static String formatC2s(VhrpC2sMessage message) {
    return switch (message) {
      SessionOpenMsg m => _formatSessionOpen(m),
      AudioTurnModeSetMsg m => 'audio.turn.mode.set {mode: ${m.mode}}',
      SessionInstructionsSetMsg m => _formatSessionInstructionsSet(m),
      LiveAudioChunkMsg m =>
        'live.audio.chunk {sequence: ${m.sequence}, pcm: ${_blobSummary(m.pcm)}}',
      TurnAudioSubmitMsg m => _formatTurnAudioSubmit(m),
      TurnTextSubmitMsg m => _formatTurnTextSubmit(m),
      TurnImageSubmitMsg m => _formatTurnImageSubmit(m),
      ToolsSetMsg m =>
        'tools.set {messageId: ${m.messageId}, tools: [${m.tools.map((t) => t.name).join(', ')}]}',
      SessionExtensionApplyMsg m =>
        'session.extension.apply {messageId: ${m.messageId}, extensionType: ${m.extensionType}}',
      ToolResultSubmitMsg m => _formatToolResultSubmit(m),
      AssistantInterruptMsg m => 'assistant.interrupt {reason: ${m.reason}}',
      SessionEndMsg() => 'session.end',
      ThreadSyncRequestMsg m =>
        'thread.sync.request {messageId: ${m.messageId}, reason: ${m.reason}}',
    };
  }

  // ── S2C ───────────────────────────────────────────────────────────────────

  /// Formats a server-to-client [message] as a readable diagnostic string.
  static String formatS2c(VhrpS2cMessage message) {
    return switch (message) {
      SessionReadyMsg m => _formatSessionReady(m),
      SessionResumedMsg m => _formatSessionResumed(m),
      AckMsg m =>
        'ack {replyTo: ${m.replyTo}, accepted: ${m.accepted}, applied: ${m.applied}, clientItemId: ${m.clientItemId}}',
      ThreadSnapshotMsg m =>
        'thread.snapshot {threadId: ${m.threadId}, items: ${m.items.length}}',
      ThreadPatchMsg m => _formatThreadPatch(m),
      AssistantAudioChunkMsg m =>
        'assistant.audio.chunk {itemId: ${m.itemId}, contentIndex: ${m.contentIndex}, pcm: ${_blobSummary(m.pcm)}}',
      AssistantAudioDoneMsg m =>
        'assistant.audio.done {itemId: ${m.itemId}, contentIndex: ${m.contentIndex}}',
      VadStateMsg m => 'vad.state {isSpeaking: ${m.isSpeaking}}',
      ErrorMsg m =>
        'error {replyTo: ${m.replyTo}, code: ${m.code}, recoverable: ${m.recoverable}, message: ${_truncateOperationalStr(m.message)}}',
      UnknownTypeS2cMsg m => 'unknown {type: ${m.unknownType}}',
    };
  }

  // ── Private C2S helpers ───────────────────────────────────────────────────

  static String _formatSessionOpen(SessionOpenMsg m) {
    final sb = StringBuffer('session.open {');
    sb.write('messageId: ${m.messageId}');
    sb.write(', speedDialId: ${m.speedDialId}');
    sb.write(', audioTurnMode: ${m.audioTurnMode}');
    if (m.resume != null) sb.write(', resumeSessionId: ${m.resume!.sessionId}');
    sb.write('}');
    return sb.toString();
  }

  static String _formatSessionInstructionsSet(SessionInstructionsSetMsg m) {
    final instr = _truncateOperationalStr(m.instructions);
    return 'session.instructions.set {messageId: ${m.messageId}, instructions: $instr}';
  }

  static String _formatTurnAudioSubmit(TurnAudioSubmitMsg m) =>
      'turn.audio.submit {messageId: ${m.messageId}, clientItemId: ${m.clientItemId}'
      ', pcm: ${_blobSummary(m.pcm)}'
      ', sampleRate: ${m.sampleRate}, channels: ${m.channels}, bitDepth: ${m.bitDepth}}';

  static String _formatTurnTextSubmit(TurnTextSubmitMsg m) =>
      'turn.text.submit {messageId: ${m.messageId}, clientItemId: ${m.clientItemId}'
      ', text: ${_verbatimText(m.text)}}';

  static String _formatTurnImageSubmit(TurnImageSubmitMsg m) =>
      'turn.image.submit {messageId: ${m.messageId}, clientItemId: ${m.clientItemId}'
      ', imageBytes: ${_blobSummary(m.imageBytes)}}';

  static String _formatToolResultSubmit(ToolResultSubmitMsg m) {
    final sb = StringBuffer('tool.result.submit {');
    sb.write('messageId: ${m.messageId}');
    sb.write(', clientItemId: ${m.clientItemId}');
    sb.write(', callId: ${m.callId}');
    sb.write(', disposition: ${m.disposition}');
    sb.write(', output: ${_verbatimText(m.output)}');
    if (m.errorMessage != null) {
      sb.write(', errorMessage: ${_truncateOperationalStr(m.errorMessage!)}');
    }
    sb.write('}');
    return sb.toString();
  }

  // ── Private S2C helpers ───────────────────────────────────────────────────

  static String _formatSessionReady(SessionReadyMsg m) {
    final sb = StringBuffer('session.ready {');
    sb.write('replyTo: ${m.replyTo}');
    sb.write(', sessionId: ${m.sessionId}');
    sb.write(', threadId: ${m.threadId}');
    if (m.conversationId != null) {
      sb.write(', conversationId: ${m.conversationId}');
    }
    if (m.capabilityExtensions.isNotEmpty) {
      sb.write(', capabilities: [${m.capabilityExtensions.join(', ')}]');
    }
    sb.write('}');
    return sb.toString();
  }

  static String _formatSessionResumed(SessionResumedMsg m) {
    final sb = StringBuffer('session.resumed {');
    sb.write('replyTo: ${m.replyTo}');
    sb.write(', sessionId: ${m.sessionId}');
    sb.write(', threadId: ${m.threadId}');
    if (m.conversationId != null) {
      sb.write(', conversationId: ${m.conversationId}');
    }
    sb.write('}');
    return sb.toString();
  }

  static String _formatThreadPatch(ThreadPatchMsg m) {
    final opSummaries = m.ops.map(_formatOp).join(', ');
    return 'thread.patch {ops: [$opSummaries]}';
  }

  static String _formatOp(ThreadPatchOp op) {
    return switch (op) {
      AddItemOp o => _formatAddItem(o),
      RemoveItemOp o => 'remove_item(${o.itemId})',
      SetStatusOp o => 'set_status(${o.itemId}, ${o.status})',
      SetRoleOp o => 'set_role(${o.itemId}, ${o.role})',
      SetFieldOp o =>
        'set_field(${o.itemId}, ${o.field}=${_sanitiseValue(o.value)})',
      PutPartOp o =>
        'put_part(${o.itemId}, ci=${o.contentIndex}, type=${_sanitiseMap(o.part)['type'] ?? '?'})',
      AppendTextOp o =>
        'append_text(${o.itemId}, ci=${o.contentIndex}, delta=${_verbatimText(o.delta)})',
      ReplaceTextOp o =>
        'replace_text(${o.itemId}, ci=${o.contentIndex}, text=${_verbatimText(o.text)})',
      AppendTranscriptOp o =>
        'append_transcript(${o.itemId}, ci=${o.contentIndex}, delta=${_verbatimText(o.delta)})',
      ReplaceTranscriptOp o =>
        'replace_transcript(${o.itemId}, ci=${o.contentIndex}, text=${_verbatimText(o.text)})',
      SetConversationIdOp o => 'set_conversation_id(${o.conversationId})',
      UnknownOp o => 'unknown_op(${o.unknownOp})',
    };
  }

  static String _formatAddItem(AddItemOp op) {
    final item = _sanitiseMap(op.item);
    final content = item['content'];
    final firstPart = content is List<Object?> && content.isNotEmpty
        ? content.first
        : null;
    final firstPartMap = firstPart is Map<String, Object?> ? firstPart : null;
    return 'add_item('
        'id=${item['id'] ?? '?'}, '
        'type=${item['type'] ?? '?'}, '
        'role=${item['role']}, '
        'status=${item['status']}, '
        'displayState=${item['displayState']}, '
        'contentCount=${content is List<Object?> ? content.length : 0}, '
        'firstPart.type=${firstPartMap?['type']}, '
        'firstPart.text=${firstPartMap?['text']}, '
        'firstPart.transcript=${firstPartMap?['transcript']}'
        ')';
  }

  // ── Shared sanitisation helpers ───────────────────────────────────────────

  /// Returns `<bytes: N>` where N is the byte count of [data].
  ///
  /// The actual bytes are NEVER included in the output.
  /// base64 encoding is explicitly forbidden per the requirements.
  static String _blobSummary(Uint8List data) => '<bytes: ${data.length}>';

  /// Keeps actual text/transcript payloads verbatim.
  static String _verbatimText(String value) => value;

  /// Truncates operational strings only: errors, instructions, identifiers, etc.
  static String _truncateOperationalStr(String value) {
    if (value.length <= maxOperationalStringLength) return value;
    return '${value.substring(0, maxOperationalStringLength)}…';
  }

  /// Recursively sanitises [map] so that:
  ///   - [Uint8List] values become `<bytes: N>`.
  ///   - [List<int>] values become `<bytes: N>`.
  ///   - Nested [Map<String, Object?>] values are recursively sanitised.
  ///   - Nested [List<Object?>] items are recursively sanitised.
  ///   - [String] values are preserved verbatim.
  ///
  /// Returns a new Map; the original is not mutated.
  static Map<String, Object?> _sanitiseMap(Map<String, Object?> map) {
    return {
      for (final entry in map.entries) entry.key: _sanitiseValue(entry.value),
    };
  }

  static Object? _sanitiseValue(Object? value) {
    return switch (value) {
      null => null,
      Uint8List v => '<bytes: ${v.length}>',
      // List<int> from CBOR decoder on some platforms
      List<int> v => '<bytes: ${v.length}>',
      String v => _verbatimText(v),
      Map<String, Object?> v => _sanitiseMap(v),
      List<Object?> v => v.map(_sanitiseValue).toList(),
      _ => value,
    };
  }
}
