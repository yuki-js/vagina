import 'dart:convert';

import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';

const interruptedToolCallErrorMessage =
    'Tool call cancelled by user interrupt.';

enum RealtimeToolStage { generating, executing, completed, error, cancelled }

Map<int, int> matchCompletedToolOutputIndices(List<RealtimeThreadItem> items) {
  final matchedToolOutputIndices = <int, int>{};
  final pendingCallIndicesByCallId = <String, List<int>>{};

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.type == RealtimeThreadItemType.functionCall &&
        item.callId != null) {
      pendingCallIndicesByCallId
          .putIfAbsent(item.callId!, () => <int>[])
          .add(i);
    }

    if (item.type == RealtimeThreadItemType.functionCallOutput &&
        item.callId != null) {
      final pendingCalls = pendingCallIndicesByCallId[item.callId!];
      if (pendingCalls != null && pendingCalls.isNotEmpty) {
        matchedToolOutputIndices[pendingCalls.removeAt(0)] = i;
      }
    }
  }

  return matchedToolOutputIndices;
}

ResolvedRealtimeToolCall? resolveRealtimeToolCall(
  List<RealtimeThreadItem> items,
  String itemId,
) {
  int? targetIndex;
  for (int i = 0; i < items.length; i++) {
    if (items[i].id == itemId) {
      targetIndex = i;
      break;
    }
  }

  if (targetIndex == null) {
    return null;
  }

  final callItem = items[targetIndex];
  if (callItem.type != RealtimeThreadItemType.functionCall) {
    return null;
  }

  final matchedToolOutputIndices = matchCompletedToolOutputIndices(items);
  return ResolvedRealtimeToolCall.fromThread(
    items,
    targetIndex,
    matchedToolOutputIndices,
  );
}

Map<String, RealtimeToolStage> resolveRealtimeToolStagesByItemId(
  List<RealtimeThreadItem> items,
) {
  final matchedToolOutputIndices = matchCompletedToolOutputIndices(items);
  final stages = <String, RealtimeToolStage>{};

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.type != RealtimeThreadItemType.functionCall) {
      continue;
    }
    stages[item.id] = ResolvedRealtimeToolCall.fromThread(
      items,
      i,
      matchedToolOutputIndices,
    ).stage;
  }

  return stages;
}

bool isRealtimeFunctionCallAcceptingOutput(
  List<RealtimeThreadItem> items, {
  required String functionCallItemId,
  required String callId,
}) {
  if (callId.isEmpty) {
    return false;
  }

  final matchedToolOutputIndices = matchCompletedToolOutputIndices(items);
  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.id != functionCallItemId) {
      continue;
    }
    if (item.type != RealtimeThreadItemType.functionCall) {
      return false;
    }
    if (item.callId != callId) {
      return false;
    }
    if (item.status == RealtimeThreadItemStatus.incomplete) {
      return false;
    }
    return !matchedToolOutputIndices.containsKey(i);
  }

  return false;
}

final class ResolvedRealtimeToolCall {
  final RealtimeThreadItem callItem;
  final RealtimeThreadItem? outputItem;
  final bool hasCompletedOutput;

  const ResolvedRealtimeToolCall({
    required this.callItem,
    required this.outputItem,
    required this.hasCompletedOutput,
  });

  factory ResolvedRealtimeToolCall.fromThread(
    List<RealtimeThreadItem> items,
    int targetIndex,
    Map<int, int>? matchedToolOutputIndices,
  ) {
    final callItem = items[targetIndex];
    if (callItem.type != RealtimeThreadItemType.functionCall) {
      throw ArgumentError.value(
        callItem.type,
        'callItem.type',
        'Expected a function call item.',
      );
    }

    final outputIndex = matchedToolOutputIndices?[targetIndex];
    return ResolvedRealtimeToolCall(
      callItem: callItem,
      outputItem: outputIndex == null ? null : items[outputIndex],
      hasCompletedOutput: outputIndex != null,
    );
  }

  String? get arguments => callItem.arguments;

  bool get hasArguments => (arguments ?? '').isNotEmpty;

  String? get output => outputItem?.output ?? callItem.output;

  bool get hasOutput => (output ?? '').isNotEmpty;

  RealtimeToolOutputDisposition? get outputDisposition =>
      outputItem?.toolOutputDisposition ?? callItem.toolOutputDisposition;

  String? get errorMessage =>
      outputItem?.toolErrorMessage ?? callItem.toolErrorMessage;

  bool get isInterruptedByUserCancellation => _isInterruptedToolCancellation(
    disposition: outputDisposition,
    output: output,
    errorMessage: errorMessage,
  );

  RealtimeToolStage get stage {
    if (callItem.status == RealtimeThreadItemStatus.incomplete) {
      return RealtimeToolStage.cancelled;
    }
    if (isInterruptedByUserCancellation) {
      return RealtimeToolStage.cancelled;
    }
    if (outputDisposition == RealtimeToolOutputDisposition.error) {
      return RealtimeToolStage.error;
    }
    if (hasCompletedOutput) {
      return RealtimeToolStage.completed;
    }
    if (callItem.status == RealtimeThreadItemStatus.completed) {
      return RealtimeToolStage.executing;
    }
    return RealtimeToolStage.generating;
  }

  bool get isError => stage == RealtimeToolStage.error;

  bool get isCancelled => stage == RealtimeToolStage.cancelled;

  bool get isRunning =>
      stage == RealtimeToolStage.generating ||
      stage == RealtimeToolStage.executing;

  String get statusName => switch (stage) {
    RealtimeToolStage.generating => 'generating',
    RealtimeToolStage.executing => 'executing',
    RealtimeToolStage.completed => 'completed',
    RealtimeToolStage.error => 'error',
    RealtimeToolStage.cancelled => 'cancelled',
  };
}

bool _isInterruptedToolCancellation({
  required RealtimeToolOutputDisposition? disposition,
  required String? output,
  required String? errorMessage,
}) {
  if (disposition != RealtimeToolOutputDisposition.error) {
    return false;
  }
  if (errorMessage == interruptedToolCallErrorMessage) {
    return true;
  }

  final outputText = output;
  if (outputText == null || outputText.isEmpty) {
    return false;
  }

  try {
    final decoded = jsonDecode(outputText);
    if (decoded is Map<String, dynamic>) {
      return decoded['error'] == interruptedToolCallErrorMessage;
    }
  } catch (_) {
    // Fall through to the wire-compatible string guard below.
  }

  return outputText.contains(interruptedToolCallErrorMessage);
}
