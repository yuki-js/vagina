// VHRP/1 thread projector — Step 4.
//
// Translates wire-level `thread.snapshot` and `thread.patch` messages into
// mutations on the client's [RealtimeThread] model.
//
// Design contract (handoff doc §5.4, §5.5, §8):
//   • snapshot → full replacement: a brand-new [RealtimeThread] is
//     constructed from the snapshot items and returned to the caller.
//     [RealtimeThread.id] is `final`, so replacement is achieved by the
//     adapter swapping its `_thread` reference rather than mutating in-place.
//   • patch   → in-place mutation of the given [RealtimeThread], applying
//     each op in arrival order (no version reconciliation).
//   • add_item idempotency: if item.id already exists locally the incoming
//     data is merged on top rather than duplicated (§5.5, §8 — pre-numbered
//     client items must unify with server canonical items).
//   • desync: any unapplicable op (missing target item) or [UnknownOp] causes
//     the projector to return a result with [ProjectResult.desync] == true.
//     The caller must then send `thread.sync.request` and apply the returned
//     snapshot before continuing.
//
// Audio note (§5.6):
//   audio parts created here carry transcript only; [audioChunks] is always
//   empty at this layer.  Raw PCM accumulation into audioChunks is Step 6's
//   responsibility.

import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type
// ─────────────────────────────────────────────────────────────────────────────

/// Outcome of a single [VhrpThreadProjector] operation.
///
/// [desync] == true means the projector detected an inconsistency (an op
/// targeted a non-existent item, or an [UnknownOp] was encountered).  The
/// caller should send `thread.sync.request` immediately.
final class ProjectResult {
  final bool desync;
  final String? desyncReason;

  const ProjectResult({this.desync = false, this.desyncReason});
  const ProjectResult.ok() : this();
  const ProjectResult.desynced(String reason)
      : desync = true,
        desyncReason = reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// Projector
// ─────────────────────────────────────────────────────────────────────────────

/// Stateless helper that projects VHRP wire ops onto [RealtimeThread].
///
/// Both public methods are free of side effects on anything other than the
/// [RealtimeThread] passed in (or returned), which makes them straightforward
/// to unit-test without mocking.
final class VhrpThreadProjector {
  const VhrpThreadProjector();

  // ── Snapshot ──────────────────────────────────────────────────────────────

  /// Builds a fresh [RealtimeThread] from [msg], discarding any previous
  /// local state.  The caller must replace its stored thread reference with
  /// the returned value.
  ///
  /// Audio parts from the snapshot carry only transcript; audioChunks is empty
  /// (past audio waveforms are not re-sent by the server — §5.4).
  RealtimeThread applySnapshot(ThreadSnapshotMsg msg) {
    final items = <RealtimeThreadItem>[];
    for (final rawItem in msg.items) {
      final item = _itemFromMap(rawItem);
      if (item != null) items.add(item);
    }
    return RealtimeThread(
      id: msg.threadId,
      conversationId: msg.conversationId,
      items: items,
    );
  }

  // ── Patch ─────────────────────────────────────────────────────────────────

  /// Applies [msg]'s ops to [thread] in arrival order.
  ///
  /// Returns [ProjectResult.ok] when all ops succeed; returns a desynced
  /// result as soon as one op cannot be applied (target item missing or
  /// [UnknownOp] encountered) — remaining ops are NOT applied after the first
  /// failure per §5.5.
  ProjectResult applyPatch(ThreadPatchMsg msg, RealtimeThread thread) {
    for (final op in msg.ops) {
      final result = _applyOp(op, thread);
      if (result.desync) return result;
    }
    return const ProjectResult.ok();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private — op dispatch
  // ─────────────────────────────────────────────────────────────────────────

  ProjectResult _applyOp(ThreadPatchOp op, RealtimeThread thread) {
    return switch (op) {
      AddItemOp op => _applyAddItem(op, thread),
      RemoveItemOp op => _applyRemoveItem(op, thread),
      SetStatusOp op => _applySetStatus(op, thread),
      SetRoleOp op => _applySetRole(op, thread),
      SetFieldOp op => _applySetField(op, thread),
      PutPartOp op => _applyPutPart(op, thread),
      AppendTextOp op => _applyAppendText(op, thread),
      ReplaceTextOp op => _applyReplaceText(op, thread),
      AppendTranscriptOp op => _applyAppendTranscript(op, thread),
      ReplaceTranscriptOp op => _applyReplaceTranscript(op, thread),
      SetConversationIdOp op => _applySetConversationId(op, thread),
      UnknownOp op => ProjectResult.desynced(
          'Encountered unknown op "${op.unknownOp}" — desync required.',
        ),
    };
  }

  // ── add_item ──────────────────────────────────────────────────────────────

  /// Adds a new item or merges onto an existing one with the same id.
  ///
  /// Merge rules (idempotency — §5.5, §8):
  ///   - scalar fields (role, status, callId, name, arguments, output,
  ///     toolOutputDisposition, toolErrorMessage) are updated with the
  ///     incoming value only if incoming is non-null.
  ///   - content parts: if the existing item has no content and the incoming
  ///     item has content parts, they are added.  Existing content is never
  ///     erased (audioChunks accumulated in step 6 must not be lost).
  ProjectResult _applyAddItem(AddItemOp op, RealtimeThread thread) {
    final incoming = _itemFromMap(op.item);
    if (incoming == null) {
      // Malformed item map — treat as desync.
      return const ProjectResult.desynced(
        'add_item received an item map without a valid id or type.',
      );
    }

    final existing = thread.findItem(incoming.id);
    if (existing != null) {
      // Merge: update fields only if incoming has a non-null value.
      if (incoming.role != null) existing.role = incoming.role;
      existing.status = incoming.status;
      if (incoming.callId != null) existing.callId = incoming.callId;
      if (incoming.name != null) existing.name = incoming.name;
      if (incoming.arguments != null) existing.arguments = incoming.arguments;
      if (incoming.output != null) existing.output = incoming.output;
      if (incoming.toolOutputDisposition != null) {
        existing.toolOutputDisposition = incoming.toolOutputDisposition;
      }
      if (incoming.toolErrorMessage != null) {
        existing.toolErrorMessage = incoming.toolErrorMessage;
      }
      existing.displayState = incoming.displayState;
      // Add content parts only if the existing item has none.
      if (existing.content.isEmpty && incoming.content.isNotEmpty) {
        for (final part in incoming.content) {
          existing.addContentPart(part);
        }
      }
    } else {
      thread.addItem(incoming);
    }
    return const ProjectResult.ok();
  }

  // ── remove_item ───────────────────────────────────────────────────────────

  ProjectResult _applyRemoveItem(RemoveItemOp op, RealtimeThread thread) {
    // remove_item on a non-existent id is silently tolerated (idempotent
    // delete is not a desync — the item may already have been removed).
    thread.removeItem(op.itemId);
    return const ProjectResult.ok();
  }

  // ── set_status ────────────────────────────────────────────────────────────

  ProjectResult _applySetStatus(SetStatusOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'set_status: item "${op.itemId}" not found — desync required.',
      );
    }
    item.status = RealtimeThreadItemStatus.fromWireValue(op.status);
    return const ProjectResult.ok();
  }

  // ── set_role ──────────────────────────────────────────────────────────────

  ProjectResult _applySetRole(SetRoleOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'set_role: item "${op.itemId}" not found — desync required.',
      );
    }
    item.role = _mapRole(op.role);
    return const ProjectResult.ok();
  }

  // ── set_field ─────────────────────────────────────────────────────────────

  ProjectResult _applySetField(SetFieldOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'set_field: item "${op.itemId}" not found — desync required.',
      );
    }
    switch (op.field) {
      case 'callId':
        item.callId = op.value as String?;
      case 'name':
        item.name = op.value as String?;
      case 'arguments':
        item.arguments = op.value as String?;
      case 'output':
        item.output = op.value as String?;
      case 'toolOutputDisposition':
        item.toolOutputDisposition =
            _mapToolOutputDisposition(op.value as String?);
      case 'toolErrorMessage':
        item.toolErrorMessage = op.value as String?;
      case 'displayState':
        item.displayState =
            RealtimeThreadItemDisplayState.fromWireValue(op.value as String?);
      default:
        // Unknown field — silently ignore (forward-compatible, not a desync).
        break;
    }
    return const ProjectResult.ok();
  }

  // ── put_part ──────────────────────────────────────────────────────────────

  ProjectResult _applyPutPart(PutPartOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'put_part: item "${op.itemId}" not found — desync required.',
      );
    }
    final part = _partFromMap(op.part);
    if (part == null) {
      // Unknown part type — silently ignore (forward-compatible).
      return const ProjectResult.ok();
    }
    item.putContentPart(part, contentIndex: op.contentIndex);
    return const ProjectResult.ok();
  }

  // ── append_text ───────────────────────────────────────────────────────────

  ProjectResult _applyAppendText(AppendTextOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'append_text: item "${op.itemId}" not found — desync required.',
      );
    }
    final part = item.findContentPart(op.contentIndex);
    if (part is! RealtimeThreadTextPart) {
      return ProjectResult.desynced(
        'append_text: content[${op.contentIndex}] on item "${op.itemId}" '
        'is not a text part — desync required.',
      );
    }
    part.appendDelta(op.delta);
    return const ProjectResult.ok();
  }

  // ── replace_text ──────────────────────────────────────────────────────────

  ProjectResult _applyReplaceText(ReplaceTextOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'replace_text: item "${op.itemId}" not found — desync required.',
      );
    }
    final part = item.findContentPart(op.contentIndex);
    if (part is! RealtimeThreadTextPart) {
      return ProjectResult.desynced(
        'replace_text: content[${op.contentIndex}] on item "${op.itemId}" '
        'is not a text part — desync required.',
      );
    }
    part.replaceText(op.text);
    return const ProjectResult.ok();
  }

  // ── append_transcript ─────────────────────────────────────────────────────

  ProjectResult _applyAppendTranscript(
      AppendTranscriptOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'append_transcript: item "${op.itemId}" not found — desync required.',
      );
    }
    final part = item.findContentPart(op.contentIndex);
    if (part is! RealtimeThreadAudioPart) {
      return ProjectResult.desynced(
        'append_transcript: content[${op.contentIndex}] on item '
        '"${op.itemId}" is not an audio part — desync required.',
      );
    }
    part.appendTranscriptDelta(op.delta);
    return const ProjectResult.ok();
  }

  // ── replace_transcript ────────────────────────────────────────────────────

  ProjectResult _applyReplaceTranscript(
      ReplaceTranscriptOp op, RealtimeThread thread) {
    final item = thread.findItem(op.itemId);
    if (item == null) {
      return ProjectResult.desynced(
        'replace_transcript: item "${op.itemId}" not found — desync required.',
      );
    }
    final part = item.findContentPart(op.contentIndex);
    if (part is! RealtimeThreadAudioPart) {
      return ProjectResult.desynced(
        'replace_transcript: content[${op.contentIndex}] on item '
        '"${op.itemId}" is not an audio part — desync required.',
      );
    }
    part.replaceTranscript(op.text);
    return const ProjectResult.ok();
  }

  // ── set_conversation_id ───────────────────────────────────────────────────

  ProjectResult _applySetConversationId(
      SetConversationIdOp op, RealtimeThread thread) {
    thread.conversationId = op.conversationId;
    return const ProjectResult.ok();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private — object construction from opaque maps
  // ─────────────────────────────────────────────────────────────────────────

  /// Parses an opaque item map (from snapshot or add_item) into a
  /// [RealtimeThreadItem].  Returns null if the map lacks a valid `id`.
  RealtimeThreadItem? _itemFromMap(Map<String, Object?> map) {
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;

    final type = _mapItemType(map['type'] as String?);
    final role = _mapRole(map['role'] as String?);
    final status = RealtimeThreadItemStatus.fromWireValue(
      map['status'] as String?,
    );

    final item = RealtimeThreadItem(
      id: id,
      type: type,
      role: role,
      status: status,
      displayState: RealtimeThreadItemDisplayState.fromWireValue(
        map['displayState'] as String?,
      ),
      callId: map['callId'] as String?,
      name: map['name'] as String?,
      arguments: map['arguments'] as String?,
      output: map['output'] as String?,
      toolOutputDisposition: _mapToolOutputDisposition(
        map['toolOutputDisposition'] as String?,
      ),
      toolErrorMessage: map['toolErrorMessage'] as String?,
    );

    // Parse content parts if present.
    final rawContent = map['content'];
    if (rawContent is List) {
      for (final rawPart in rawContent) {
        if (rawPart is Map<String, Object?>) {
          final part = _partFromMap(rawPart);
          if (part != null) item.addContentPart(part);
        }
      }
    }

    return item;
  }

  /// Parses a part map `{ type, isDone, ... }` into a content part.
  ///
  /// Returns null for unknown part types (forward-compatible).
  RealtimeThreadContentPart? _partFromMap(Map<String, Object?> map) {
    final type = map['type'] as String?;
    final isDone = map['isDone'] as bool? ?? false;
    return switch (type) {
      'text' => RealtimeThreadTextPart(
          text: map['text'] as String? ?? '',
          isDone: isDone,
        ),
      'audio' => RealtimeThreadAudioPart(
          // audioChunks deliberately left empty at this layer — §5.6.
          transcript: map['transcript'] as String?,
          isDone: isDone,
        ),
      'image' => RealtimeThreadImagePart(
          imageUrl: map['imageUrl'] as String? ?? '',
          detail: map['detail'] as String? ?? 'auto',
        ),
      _ => null, // Unknown part type — silently ignored.
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private — enum mapping
  // ─────────────────────────────────────────────────────────────────────────

  RealtimeThreadItemType _mapItemType(String? value) {
    return switch (value) {
      'function_call' => RealtimeThreadItemType.functionCall,
      'function_call_output' => RealtimeThreadItemType.functionCallOutput,
      _ => RealtimeThreadItemType.message,
    };
  }

  RealtimeThreadItemRole? _mapRole(String? value) {
    return switch (value) {
      'system' => RealtimeThreadItemRole.system,
      'user' => RealtimeThreadItemRole.user,
      'assistant' => RealtimeThreadItemRole.assistant,
      _ => null,
    };
  }

  RealtimeToolOutputDisposition? _mapToolOutputDisposition(String? value) {
    return switch (value) {
      'success' => RealtimeToolOutputDisposition.success,
      'error' => RealtimeToolOutputDisposition.error,
      _ => null,
    };
  }
}
