// Shared RealtimeAdapter contract test suite.
//
// Usage: call [runRealtimeAdapterContractTests] from a test file, passing a
// concrete [AdapterHarness] implementation.  The same set of tests runs
// against every harness, proving "warp transparency" — both OAI (standalone)
// and VHRP (hosted) adapters behave identically from the app's perspective.
//
// Test naming convention (§9.3 of handoff doc):
//   Each test declares which user-facing contract it guards and which user
//   experience would break if the behaviour changed.

import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Harness abstraction
// ─────────────────────────────────────────────────────────────────────────────

/// Backend harness that both adapter implementations must satisfy.
///
/// A harness wraps one adapter instance and provides the "other end" of the
/// conversation (mock provider / mock VHRP server) through abstract operations.
abstract class AdapterHarness {
  /// The adapter under test.
  RealtimeAdapter get adapter;

  /// Called inside [setUp] — create and configure the adapter + backend fake.
  Future<void> setUp();

  /// Called inside [tearDown] — dispose the adapter and any resources.
  Future<void> tearDown();

  /// Connect the adapter and wait until fully connected.
  Future<void> connect();

  /// Drain pending microtasks.  Call after any operation that emits events
  /// asynchronously so stream listeners run before assertions.
  Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

  /// Simulate the backend sending a complete assistant text response to a
  /// previously-sent user text turn.
  ///
  /// After this future completes (plus a [pumpEvents]):
  ///   - An item with [userItemId] exists, role=user, status=completed.
  ///   - An item with [assistantItemId] exists, role=assistant,
  ///     status=completed, with a text content-part == [responseText].
  Future<void> simulateAssistantTextReply({
    required String userItemId,
    required String assistantItemId,
    required String responseText,
  });

  /// Simulate the backend notifying the client of a function-call request.
  ///
  /// After this future completes (plus a [pumpEvents]), [adapter.thread] must
  /// contain a `functionCall` item with id=[functionCallItemId],
  /// callId=[callId], name=[functionName], arguments=[arguments],
  /// status=completed.
  Future<void> simulateFunctionCallRequest({
    required String functionCallItemId,
    required String callId,
    required String functionName,
    required String arguments,
  });

  /// Drain state after [adapter.interrupt()] is called.
  Future<void> drainAfterInterrupt();
}

// ─────────────────────────────────────────────────────────────────────────────
// Contract suite entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Registers all RealtimeAdapter contract tests against [createHarness].
///
/// [label] is a human-readable name for the adapter under test.
void runRealtimeAdapterContractTests({
  required String label,
  required AdapterHarness Function() createHarness,
}) {
  group('RealtimeAdapter contract — $label', () {
    late AdapterHarness harness;

    setUp(() async {
      harness = createHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    // ── CT-1: Connection lifecycle ──────────────────────────────────────────

    group('CT-1 — connection lifecycle', () {
      test(
        'CT-1a: connect() transitions connectionState to connected; '
        'user can start a voice conversation',
        () async {
          // Contract: if connectionState never reaches connected, the user
          // sees a spinner forever and can never speak to the AI.
          expect(
            harness.adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.idle),
            reason: 'CT-1a: initial phase must be idle',
          );

          final phases = <RealtimeAdapterConnectionPhase>[];
          final sub = harness.adapter.connectionStateUpdates
              .listen((s) => phases.add(s.phase));

          await harness.connect();
          await harness.pumpEvents();

          expect(
            harness.adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.connected),
            reason: 'CT-1a: connectionState must be connected after connect()',
          );
          expect(
            phases,
            contains(RealtimeAdapterConnectionPhase.connected),
            reason: 'CT-1a: connectionStateUpdates must emit connected',
          );

          await sub.cancel();
        },
      );

      test(
        'CT-1b: connecting phase is emitted before connected; '
        'user sees a "connecting" indicator before the session opens',
        () async {
          // Contract: if connecting is skipped, the UI has no way to show a
          // progress indicator between "tap microphone" and "ready".
          final phases = <RealtimeAdapterConnectionPhase>[];
          final sub = harness.adapter.connectionStateUpdates
              .listen((s) => phases.add(s.phase));

          await harness.connect();
          await harness.pumpEvents();

          final connectingIdx =
              phases.indexOf(RealtimeAdapterConnectionPhase.connecting);
          final connectedIdx =
              phases.indexOf(RealtimeAdapterConnectionPhase.connected);

          expect(connectingIdx, greaterThanOrEqualTo(0),
              reason: 'CT-1b: connecting must be emitted');
          expect(connectedIdx, greaterThanOrEqualTo(0),
              reason: 'CT-1b: connected must be emitted');
          expect(connectingIdx, lessThan(connectedIdx),
              reason: 'CT-1b: connecting must precede connected');

          await sub.cancel();
        },
      );

      test(
        'CT-1c: dispose() makes the adapter unusable; '
        'user can exit a session without resource leaks',
        () async {
          // Contract: after dispose(), any send attempt must throw immediately
          // rather than silently sending to a closed session.  This prevents
          // ghost messages appearing while the user believes the session ended.
          //
          // Note on connectionState: VhrpRealtimeAdapter does not emit a
          // "disconnected" state phase on dispose (it just closes resources).
          // The shared contract therefore asserts functional unusability via a
          // method-call rather than a connectionState phase assertion, so that
          // both adapters can satisfy it.
          await harness.connect();
          await harness.adapter.dispose();

          // After dispose(), sendText must throw StateError.
          expect(
            () => harness.adapter.sendText('post-dispose'),
            throwsA(isA<StateError>()),
            reason: 'CT-1c: sendText after dispose() must throw StateError',
          );
        },
      );
    });

    // ── CT-2: sendText / user item ──────────────────────────────────────────

    group('CT-2 — sendText returns local item ID', () {
      test(
        'CT-2a: sendText returns a non-empty local item ID; '
        'app can correlate thread items with the send that caused them',
        () async {
          // Contract: without a stable local ID, the app cannot highlight or
          // track the message the user just sent.
          await harness.connect();

          final itemId = await harness.adapter.sendText('こんにちは');

          expect(itemId, isNotEmpty,
              reason: 'CT-2a: itemId must be non-empty');
          expect(itemId.length, lessThanOrEqualTo(64),
              reason: 'CT-2a: itemId must be ≤ 64 chars');
        },
      );

      test(
        'CT-2b: consecutive sendText calls produce unique IDs; '
        'each message is independently addressable in the thread',
        () async {
          // Contract: duplicate IDs would cause messages to merge incorrectly
          // in the thread, corrupting the conversation history shown to the user.
          await harness.connect();

          final ids = <String>{};
          for (var i = 0; i < 4; i++) {
            ids.add(await harness.adapter.sendText('msg $i'));
            await harness.pumpEvents();
          }

          expect(ids.length, equals(4),
              reason: 'CT-2b: all itemIds must be distinct');
        },
      );
    });

    // ── CT-3: Full text round-trip ──────────────────────────────────────────

    group('CT-3 — full text round-trip', () {
      test(
        'CT-3a: after sendText + full assistant reply, thread has a completed '
        'user item and a completed assistant message item with the response text; '
        'user reads the AI reply in the conversation view',
        () async {
          // Contract: if the user item or assistant item is missing / incomplete,
          // the conversation view shows a blank or spinning entry instead of the
          // exchange the user had with the AI.
          await harness.connect();

          const assistantItemId = 'asst-item-001';
          const responseText = 'こんにちは、何かご用でしょうか？';

          final userItemId = await harness.adapter.sendText('こんにちは');

          await harness.simulateAssistantTextReply(
            userItemId: userItemId,
            assistantItemId: assistantItemId,
            responseText: responseText,
          );
          await harness.pumpEvents();

          // User item must be present with completed status.
          final userItem = harness.adapter.thread.findItem(userItemId);
          expect(userItem, isNotNull,
              reason: 'CT-3a: user item must be in thread');
          expect(userItem!.type, equals(RealtimeThreadItemType.message),
              reason: 'CT-3a: user item type == message');
          expect(userItem.role, equals(RealtimeThreadItemRole.user),
              reason: 'CT-3a: user item role == user');
          expect(userItem.status, equals(RealtimeThreadItemStatus.completed),
              reason: 'CT-3a: user item must be completed');

          // Assistant item must be present with the text content.
          final assistantItem =
              harness.adapter.thread.findItem(assistantItemId);
          expect(assistantItem, isNotNull,
              reason: 'CT-3a: assistant item must be in thread');
          expect(assistantItem!.type, equals(RealtimeThreadItemType.message),
              reason: 'CT-3a: assistant item type == message');
          expect(assistantItem.role,
              equals(RealtimeThreadItemRole.assistant),
              reason: 'CT-3a: assistant item role == assistant');
          expect(assistantItem.status,
              equals(RealtimeThreadItemStatus.completed),
              reason: 'CT-3a: assistant item must be completed');

          // Text part must contain the response text.
          final textPart = assistantItem.content
              .whereType<RealtimeThreadTextPart>()
              .firstOrNull;
          expect(textPart, isNotNull,
              reason: 'CT-3a: assistant item must have a text part');
          expect(textPart!.text, equals(responseText),
              reason: 'CT-3a: text part must contain the assistant reply');
        },
      );

      test(
        'CT-3b: threadUpdates fires at least once during the round-trip; '
        'the UI refreshes to show new content as it streams in',
        () async {
          // Contract: without threadUpdates firing, the conversation view never
          // redraws and the user sees a static or empty chat.
          await harness.connect();

          const assistantItemId = 'asst-item-002';
          final updates = <RealtimeThread>[];
          final sub = harness.adapter.threadUpdates.listen(updates.add);

          final userItemId = await harness.adapter.sendText('Hello');
          await harness.simulateAssistantTextReply(
            userItemId: userItemId,
            assistantItemId: assistantItemId,
            responseText: 'Hi there!',
          );
          await harness.pumpEvents();

          expect(updates, isNotEmpty,
              reason: 'CT-3b: threadUpdates must fire during round-trip');

          await sub.cancel();
        },
      );
    });

    // ── CT-4: Tool call round-trip ──────────────────────────────────────────

    group('CT-4 — tool call round-trip', () {
      test(
        'CT-4a: after server sends a functionCall, thread contains the item '
        'with correct callId, name, and arguments; '
        'app can invoke the right function with the right parameters',
        () async {
          // Contract: if the functionCall item is missing or has wrong fields,
          // the tool runtime invokes the wrong function or with wrong args.
          await harness.connect();

          const fcItemId = 'fc-item-001';
          const callId = 'call_xyz_001';
          const fnName = 'search_web';
          const args = '{"query":"weather today"}';

          await harness.simulateFunctionCallRequest(
            functionCallItemId: fcItemId,
            callId: callId,
            functionName: fnName,
            arguments: args,
          );
          await harness.pumpEvents();

          final item = harness.adapter.thread.findItem(fcItemId);
          expect(item, isNotNull,
              reason: 'CT-4a: functionCall item must be in thread');
          expect(item!.type, equals(RealtimeThreadItemType.functionCall),
              reason: 'CT-4a: item type == functionCall');
          expect(item.callId, equals(callId),
              reason: 'CT-4a: callId must match');
          expect(item.name, equals(fnName),
              reason: 'CT-4a: function name must match');
          expect(item.arguments, equals(args),
              reason: 'CT-4a: arguments must match');
          expect(item.status, equals(RealtimeThreadItemStatus.completed),
              reason: 'CT-4a: functionCall item must be completed');
        },
      );

      test(
        'CT-4b: sendFunctionOutput adds a functionCallOutput item with correct '
        'callId and output; app confirms tool result is tracked in the thread',
        () async {
          // Contract: if the functionCallOutput item is missing, the app has
          // no way to know the tool result was submitted.
          await harness.connect();

          const fcItemId = 'fc-item-002';
          const callId = 'call_xyz_002';
          await harness.simulateFunctionCallRequest(
            functionCallItemId: fcItemId,
            callId: callId,
            functionName: 'get_weather',
            arguments: '{"location":"Tokyo"}',
          );
          await harness.pumpEvents();

          const outputJson = '{"temperature":22,"condition":"sunny"}';
          final outputItemId = await harness.adapter.sendFunctionOutput(
            callId: callId,
            output: outputJson,
          );
          await harness.pumpEvents();

          final outputItem = harness.adapter.thread.findItem(outputItemId);
          expect(outputItem, isNotNull,
              reason: 'CT-4b: functionCallOutput item must be in thread');
          expect(outputItem!.type,
              equals(RealtimeThreadItemType.functionCallOutput),
              reason: 'CT-4b: item type == functionCallOutput');
          expect(outputItem.callId, equals(callId),
              reason: 'CT-4b: callId must match the function call');
          expect(outputItem.output, equals(outputJson),
              reason: 'CT-4b: output must equal the submitted result');
          expect(outputItem.status, equals(RealtimeThreadItemStatus.completed),
              reason: 'CT-4b: functionCallOutput starts as completed');
        },
      );

      test(
        'CT-4c: sendFunctionOutput returns a non-empty item ID; '
        'app can reference the output item independently',
        () async {
          // Contract: without an ID the app cannot differentiate multiple
          // concurrent tool-call outputs in the thread.
          await harness.connect();

          const callId = 'call_xyz_003';
          await harness.simulateFunctionCallRequest(
            functionCallItemId: 'fc-item-003',
            callId: callId,
            functionName: 'lookup',
            arguments: '{}',
          );
          await harness.pumpEvents();

          final outputItemId = await harness.adapter.sendFunctionOutput(
            callId: callId,
            output: '{"result":"ok"}',
          );

          expect(outputItemId, isNotEmpty,
              reason: 'CT-4c: output itemId must be non-empty');
        },
      );
    });

    // ── CT-5: interrupt ─────────────────────────────────────────────────────

    group('CT-5 — interrupt', () {
      test(
        'CT-5a: interrupt() completes without error when connected; '
        'user can barge in on the AI at any point during generation',
        () async {
          // Contract: if interrupt() throws, the app cannot implement the
          // barge-in UX and the user is stuck listening to the AI finish.
          await harness.connect();

          await expectLater(
            harness.adapter.interrupt(),
            completes,
            reason: 'CT-5a: interrupt() must complete without error',
          );

          await harness.drainAfterInterrupt();
        },
      );

      test(
        'CT-5b: adapter remains connected after interrupt(); '
        'user can immediately send a new message after barging in',
        () async {
          // Contract: if the adapter disconnects on interrupt, the user
          // experiences an unexpected drop and must reconnect manually.
          await harness.connect();

          await harness.adapter.interrupt();
          await harness.drainAfterInterrupt();

          expect(
            harness.adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.connected),
            reason:
                'CT-5b: connectionState must remain connected after interrupt',
          );
        },
      );
    });

    // ── CT-6: cancelFunctionCalls ───────────────────────────────────────────

    group('CT-6 — cancelFunctionCalls', () {
      test(
        'CT-6a: cancelFunctionCalls marks a pending functionCall as incomplete; '
        'user sees stale tool results removed when they interrupt the AI',
        () async {
          // Contract: if cancelled tool items remain as completed, the app may
          // show stale tool-call results even after the user interrupted.
          await harness.connect();

          const fcItemId = 'fc-item-cancel-01';
          const callId = 'call_cancel_01';

          await harness.simulateFunctionCallRequest(
            functionCallItemId: fcItemId,
            callId: callId,
            functionName: 'lookup',
            arguments: '{}',
          );
          await harness.pumpEvents();

          final item = harness.adapter.thread.findItem(fcItemId);
          expect(item, isNotNull, reason: 'CT-6a: fc item must exist first');

          harness.adapter.cancelFunctionCalls(itemIds: {fcItemId});
          await harness.pumpEvents();

          expect(
            item!.status,
            equals(RealtimeThreadItemStatus.incomplete),
            reason: 'CT-6a: cancelled functionCall must become incomplete',
          );
        },
      );
    });
  });
}
