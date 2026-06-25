import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/realtime/tool_call_resolution.dart';

void main() {
  group('tool call resolution cancellation semantics', () {
    test(
      'interrupt cancellation output is domain-cancelled, not an ordinary tool error',
      () {
        final items = <RealtimeThreadItem>[
          RealtimeThreadItem(
            id: 'call-item',
            type: RealtimeThreadItemType.functionCall,
            status: RealtimeThreadItemStatus.completed,
            callId: 'call-1',
            name: 'calculator',
            arguments: '{"expression":"1+1"}',
          ),
          RealtimeThreadItem(
            id: 'cancel-output',
            type: RealtimeThreadItemType.functionCallOutput,
            status: RealtimeThreadItemStatus.completed,
            callId: 'call-1',
            output: '{"error":"$interruptedToolCallErrorMessage"}',
            toolOutputDisposition: RealtimeToolOutputDisposition.error,
            toolErrorMessage: interruptedToolCallErrorMessage,
          ),
        ];

        final resolved = resolveRealtimeToolCall(items, 'call-item');

        expect(resolved, isNotNull);
        expect(resolved!.stage, RealtimeToolStage.cancelled);
        expect(resolved.statusName, 'cancelled');
        expect(resolved.isError, isFalse);
      },
    );

    test('ordinary tool error remains error', () {
      final items = <RealtimeThreadItem>[
        RealtimeThreadItem(
          id: 'call-item',
          type: RealtimeThreadItemType.functionCall,
          status: RealtimeThreadItemStatus.completed,
          callId: 'call-1',
          name: 'calculator',
          arguments: '{"expression":"1/0"}',
        ),
        RealtimeThreadItem(
          id: 'error-output',
          type: RealtimeThreadItemType.functionCallOutput,
          status: RealtimeThreadItemStatus.completed,
          callId: 'call-1',
          output: '{"error":"division by zero"}',
          toolOutputDisposition: RealtimeToolOutputDisposition.error,
          toolErrorMessage: 'division by zero',
        ),
      ];

      final resolved = resolveRealtimeToolCall(items, 'call-item');

      expect(resolved, isNotNull);
      expect(resolved!.stage, RealtimeToolStage.error);
      expect(resolved.statusName, 'error');
      expect(resolved.isCancelled, isFalse);
    });
  });

  group('tool output acceptance invariant', () {
    test(
      'a delayed success is rejected after the same call was resolved by interrupt cancellation',
      () {
        final items = <RealtimeThreadItem>[
          RealtimeThreadItem(
            id: 'call-item',
            type: RealtimeThreadItemType.functionCall,
            status: RealtimeThreadItemStatus.completed,
            callId: 'call-1',
            name: 'calculator',
            arguments: '{"expression":"40+2"}',
          ),
          RealtimeThreadItem(
            id: 'cancel-output',
            type: RealtimeThreadItemType.functionCallOutput,
            status: RealtimeThreadItemStatus.completed,
            callId: 'call-1',
            output: '{"error":"$interruptedToolCallErrorMessage"}',
            toolOutputDisposition: RealtimeToolOutputDisposition.error,
            toolErrorMessage: interruptedToolCallErrorMessage,
          ),
        ];

        final acceptsLateSuccess = isRealtimeFunctionCallAcceptingOutput(
          items,
          functionCallItemId: 'call-item',
          callId: 'call-1',
        );

        expect(acceptsLateSuccess, isFalse);
      },
    );

    test(
      'a completed unresolved function call still accepts its first output',
      () {
        final items = <RealtimeThreadItem>[
          RealtimeThreadItem(
            id: 'call-item',
            type: RealtimeThreadItemType.functionCall,
            status: RealtimeThreadItemStatus.completed,
            callId: 'call-1',
            name: 'calculator',
            arguments: '{"expression":"40+2"}',
          ),
        ];

        final acceptsFirstOutput = isRealtimeFunctionCallAcceptingOutput(
          items,
          functionCallItemId: 'call-item',
          callId: 'call-1',
        );

        expect(acceptsFirstOutput, isTrue);
      },
    );
  });
}
