// Tests for VhrpRealtimeAdapter — Step 7: tools, instructions, extensions,
// pre-connect buffering, and ack/error correlation.
//
// Contract assertions (handoff doc §9.3):
//
//   C1  registerTools (connected): sends tools.set with correct name /
//       description / parameters fields; ack resolves the future.
//   C2  registerTools empty list: sends tools.set with empty array.
//   C3  registerTools (pre-connect buffer): when called before session.ready,
//       tools.set is NOT sent immediately; it IS sent after session.ready.
//   C4  registerTools last-write-wins: multiple pre-connect calls keep only
//       the last list.
//   C5  setInstructions (connected): sends session.instructions.set; ack
//       resolves future.
//   C6  setInstructions null: null is forwarded on the wire (blank → null).
//   C7  setInstructions (pre-connect): buffered; flushed after session.ready.
//   C8  applyProviderExtension ack→true: correct wire message; ack → true.
//   C9  applyProviderExtension error→false: error(extension.unsupported) → false.
//   C10 applyProviderExtension capabilities guard: key absent from
//       capabilities.extensions → false, no round-trip.
//   C11 applyProviderExtension (pre-connect): future resolves after post-ready
//       ack/error round-trip.
//   C12 ack correlation: two parallel requests resolved by their own replyTo.
//   C13 dispose: pending ack completers are cancelled with StateError.
//   C14 session.open audioTurnMode dynamic: manual mode reflected in session.open.

import 'dart:async';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart'
    show RealtimeAudioTurnMode;
import 'package:vagina/feat/call/services/realtime/realtime_provider_extensions.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared test fixtures
// ─────────────────────────────────────────────────────────────────────────────

const String _testToken = 'jwt-test-token';
const String _testModelId = 'vagina-v1-test';
final _testConfig = HostedVoiceAgentApiConfig(modelId: _testModelId);

final _tool1 = ToolDefinition(
  toolKey: 'search_web',
  displayName: 'Search',
  displayDescription: 'Search the web',
  categoryKey: 'utility',
  iconKey: 'search',
  sourceKey: 'builtin',
  publishedBy: 'test',
  description: 'Searches the web for a query.',
  parametersSchema: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string'},
    },
    'required': ['query'],
  },
);

final _tool2 = ToolDefinition(
  toolKey: 'get_weather',
  displayName: 'Weather',
  displayDescription: 'Get weather',
  categoryKey: 'utility',
  iconKey: 'weather',
  sourceKey: 'builtin',
  publishedBy: 'test',
  description: 'Gets the current weather.',
  parametersSchema: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string'},
    },
    'required': ['location'],
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

VhrpRealtimeAdapter _makeAdapter(FakeVhrpTransport fake) {
  return VhrpRealtimeAdapter(
    transport: fake,
    tokenProvider: () async => _testToken,
    urlResolver: (_) =>
        Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
  );
}

/// Yields one full event-loop turn (drains all pending microtasks then one
/// timer callback), matching the pattern used in existing connect tests.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

/// Injects a `session.ready` frame with the given [extensionKeys] into [fake].
void _injectSessionReady(
  FakeVhrpTransport fake, {
  List<String> extensionKeys = const [],
}) {
  final map = CborMap({
    CborString('type'): CborString('session.ready'),
    CborString('body'): CborMap({
      CborString('sessionId'): CborString('srv-session-001'),
      CborString('threadId'): CborString('srv-thread-001'),
      CborString('conversationId'): CborString('srv-conv-001'),
      CborString('capabilities'): CborMap({
        CborString('extensions'): CborList([
          for (final k in extensionKeys) CborString(k),
        ]),
      }),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects an `ack` frame with the given [replyTo] into [fake].
void _injectAck(FakeVhrpTransport fake, String replyTo) {
  final map = CborMap({
    CborString('type'): CborString('ack'),
    CborString('replyTo'): CborString(replyTo),
    CborString('body'): CborMap({
      CborString('accepted'): CborBool(true),
      CborString('applied'): CborBool(true),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Injects an `error` frame with the given [replyTo] and [code] into [fake].
void _injectError(
  FakeVhrpTransport fake,
  String replyTo,
  String code, {
  bool recoverable = true,
}) {
  final map = CborMap({
    CborString('type'): CborString('error'),
    CborString('replyTo'): CborString(replyTo),
    CborString('body'): CborMap({
      CborString('code'): CborString(code),
      CborString('message'): CborString('Error: $code'),
      CborString('recoverable'): CborBool(recoverable),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Decodes a CBOR frame from [fake.sentBytes] at [index].
///
/// Returns the top-level envelope fields, with [body] key holding a nested
/// map for direct access (e.g. `frame['body']['instructions']`), plus body
/// fields merged to the top level for convenience (e.g. `frame['tools']`).
Map<String, Object?> _decodeFrame(FakeVhrpTransport fake, int index) {
  expect(fake.sentBytes.length, greaterThan(index),
      reason: 'Expected at least ${index + 1} sent frames');
  final decoded = cbor.decode(fake.sentBytes[index]);
  final map = decoded as CborMap;
  final result = <String, Object?>{};
  for (final entry in map.entries) {
    final key = (entry.key as CborString).toString();
    result[key] = _cborToValue(entry.value);
  }
  // Merge body fields for easy access.
  final body = result['body'];
  if (body is Map<String, Object?>) {
    result.addAll(body);
  }
  return result;
}

Object? _cborToValue(CborValue? v) {
  return switch (v) {
    null => null,
    CborNull() => null,
    CborBool b => b.value,
    CborInt i => i.toInt(),
    CborFloat f => f.value,
    CborString s => s.toString(),
    CborBytes b => Uint8List.fromList(b.bytes),
    CborMap m => {
        for (final e in m.entries)
          if (e.key is CborString)
            (e.key as CborString).toString(): _cborToValue(e.value),
      },
    CborList l => [for (final e in l) _cborToValue(e)],
    _ => null,
  };
}

/// Starts connect() and injects session.ready; waits for the adapter to
/// reach `connected` state.
///
/// Uses [_pump()] (= `delayed(Duration.zero)`) matching the existing test
/// pattern, which drains all pending microtasks from the two async awaits
/// inside [VhrpRealtimeAdapter.connect] before the transport is connected
/// and session.open is sent.
Future<void> _connectAndReady(
  VhrpRealtimeAdapter adapter,
  FakeVhrpTransport fake, {
  List<String> extensionKeys = const [],
}) async {
  final connectFuture = adapter.connect(_testConfig);
  // One full event-loop turn lets connect() reach its session.ready wait.
  await _pump();
  _injectSessionReady(fake, extensionKeys: extensionKeys);
  await connectFuture;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late FakeVhrpTransport fake;
  late VhrpRealtimeAdapter adapter;

  setUp(() {
    fake = FakeVhrpTransport();
    adapter = _makeAdapter(fake);
  });

  tearDown(() async {
    await adapter.dispose();
  });

  // ─── C1: registerTools (connected) ────────────────────────────────────────

  test(
    'C1: registerTools sends tools.set with name/description/parameters; '
    'ack resolves future',
    () async {
      // Contract: tools.set wire message has the correct fields;
      // Future completes when server acks.
      await _connectAndReady(adapter, fake);
      final before = fake.sentBytes.length;

      final toolsFuture = adapter.registerTools([_tool1, _tool2]);

      // Exactly one new frame should have been sent.
      expect(fake.sentBytes.length, before + 1);
      final frame = _decodeFrame(fake, before);
      expect(frame['type'], 'tools.set');
      final tools = frame['tools'] as List<Object?>;
      expect(tools, hasLength(2));

      final t0 = tools[0] as Map<String, Object?>;
      expect(t0['name'], _tool1.toolKey);
      expect(t0['description'], _tool1.description);
      expect((t0['parameters'] as Map).isNotEmpty, isTrue);

      final t1 = tools[1] as Map<String, Object?>;
      expect(t1['name'], _tool2.toolKey);
      expect(t1['description'], _tool2.description);

      // Inject ack with the messageId that was sent.
      final msgId = frame['messageId'] as String;
      _injectAck(fake, msgId);
      await toolsFuture; // should complete without error
    },
  );

  // ─── C2: registerTools empty list ─────────────────────────────────────────

  test(
    'C2: registerTools([]) sends tools.set with empty tools array',
    () async {
      // Contract: empty list disables tools; wire array must be [].
      await _connectAndReady(adapter, fake);
      final before = fake.sentBytes.length;

      final toolsFuture = adapter.registerTools([]);
      final frame = _decodeFrame(fake, before);
      expect(frame['type'], 'tools.set');
      expect(frame['tools'], isEmpty);

      final msgId = frame['messageId'] as String;
      _injectAck(fake, msgId);
      await toolsFuture;
    },
  );

  // ─── C3: registerTools pre-connect buffering ──────────────────────────────

  test(
    'C3: registerTools before session.ready buffers tools; '
    'auto-sends after session.ready',
    () async {
      // Contract (handoff doc §7.1): tools.set is NOT sent before session.ready;
      // it IS auto-sent immediately after.
      final connectFuture = adapter.connect(_testConfig);

      // One pump gives connect() time to send session.open and then await
      // session.ready.  At this point sentBytes = [session.open].
      await _pump();
      final beforeCount = fake.sentBytes.length; // 1: only session.open

      // Call registerTools BEFORE session.ready.
      unawaited(adapter.registerTools([_tool1]));

      // No new frame yet — buffered.
      expect(fake.sentBytes.length, beforeCount,
          reason: 'tools.set must not be sent before session.ready');

      // Inject session.ready — adapter should flush the buffer.
      _injectSessionReady(fake);
      await _pump(); // let _flushPreConnectBuffers async work complete
      await _pump();

      // A tools.set frame should now be in the sent list.
      expect(fake.sentBytes.length, greaterThan(beforeCount),
          reason: 'tools.set must be sent after session.ready');

      final frame = _decodeFrame(fake, beforeCount);
      expect(frame['type'], 'tools.set');
      final tools = frame['tools'] as List<Object?>;
      expect(tools, hasLength(1));
      expect((tools[0] as Map<String, Object?>)['name'], _tool1.toolKey);

      // Ack the tools.set so the future completes.
      _injectAck(fake, frame['messageId'] as String);
      await connectFuture;
    },
  );

  // ─── C4: registerTools last-write-wins ────────────────────────────────────

  test(
    'C4: multiple pre-connect registerTools calls — only last list is sent',
    () async {
      // Contract: buffer is last-write-wins; only the final call matters.
      final connectFuture = adapter.connect(_testConfig);
      await _pump();
      final beforeCount = fake.sentBytes.length; // 1: session.open only

      unawaited(adapter.registerTools([_tool1])); // overwritten
      unawaited(adapter.registerTools([_tool2])); // this one wins

      _injectSessionReady(fake);
      await _pump();
      await _pump();

      // Only one tools.set frame.
      expect(fake.sentBytes.length, beforeCount + 1);
      final frame = _decodeFrame(fake, beforeCount);
      expect(frame['type'], 'tools.set');
      final tools = frame['tools'] as List<Object?>;
      expect(tools, hasLength(1));
      expect(
        (tools[0] as Map<String, Object?>)['name'],
        _tool2.toolKey,
        reason: 'Only the last registerTools call should be flushed',
      );

      _injectAck(fake, frame['messageId'] as String);
      await connectFuture;
    },
  );

  // ─── C5: setInstructions (connected) ──────────────────────────────────────

  test(
    'C5: setInstructions sends session.instructions.set; ack resolves',
    () async {
      // Contract: session.instructions.set with non-null instructions;
      // ack resolves.
      await _connectAndReady(adapter, fake);
      final before = fake.sentBytes.length;

      final instrFuture = adapter.setInstructions('You are helpful.');
      final frame = _decodeFrame(fake, before);
      expect(frame['type'], 'session.instructions.set');
      expect(frame['instructions'], 'You are helpful.');

      _injectAck(fake, frame['messageId'] as String);
      await instrFuture;
    },
  );

  // ─── C6: setInstructions empty clear ──────────────────────────────────────

  test(
    'C6: setInstructions("") sends session.instructions.set with empty string',
    () async {
      // Contract: empty instructions clears instructions; wire value is ''.
      await _connectAndReady(adapter, fake);
      final seedFuture = adapter.setInstructions('non-empty');
      final seedFrame = _decodeFrame(fake, fake.sentBytes.length - 1);
      _injectAck(fake, seedFrame['messageId'] as String);
      await seedFuture;
      final before = fake.sentBytes.length;

      final instrFuture = adapter.setInstructions('');
      final frame = _decodeFrame(fake, before);
      expect(frame['type'], 'session.instructions.set');
      expect(frame['instructions'], '');

      _injectAck(fake, frame['messageId'] as String);
      await instrFuture;
    },
  );

  // ─── C7: setInstructions pre-connect state ────────────────────────────────

  test(
    'C7: setInstructions before connect is carried by session.open',
    () async {
      // Contract: pre-connect setInstructions updates canonical session state;
      // connect carries it in session.open without a post-ready override.
      await adapter.setInstructions('Pre-connect instructions');
      final connectFuture = adapter.connect(_testConfig);
      await _pump();

      final frame = _decodeFrame(fake, 0);
      expect(frame['type'], 'session.open');
      expect(frame['instructions'], 'Pre-connect instructions');
      final beforeReadyCount = fake.sentBytes.length;

      _injectSessionReady(fake);
      await _pump();
      await _pump();

      expect(fake.sentBytes.length, beforeReadyCount,
          reason: 'pre-connect instructions are absorbed into session.open');
      await connectFuture;
    },
  );

  // ─── C8: applyProviderExtension ack→true ──────────────────────────────────

  test(
    'C8: applyProviderExtension sends session.extension.apply; ack → true',
    () async {
      // Contract: ack → returns true; correct extensionType and payload on wire.
      await _connectAndReady(
        adapter,
        fake,
        extensionKeys: [RealtimeProviderExtensions.voiceSelection],
      );
      final before = fake.sentBytes.length;

      final extFuture = adapter.applyProviderExtension(
        RealtimeProviderExtensions.voiceSelection,
        {RealtimeProviderExtensions.selectionKey: 'shimmer'},
      );

      final frame = _decodeFrame(fake, before);
      expect(frame['type'], 'session.extension.apply');
      expect(frame['extensionType'], RealtimeProviderExtensions.voiceSelection);
      final payload = frame['payload'] as Map<String, Object?>;
      expect(payload[RealtimeProviderExtensions.selectionKey], 'shimmer');

      _injectAck(fake, frame['messageId'] as String);
      final result = await extFuture;
      expect(result, isTrue);
    },
  );

  // ─── C9: applyProviderExtension error→false ───────────────────────────────

  test(
    'C9: applyProviderExtension with error(extension.unsupported) → false',
    () async {
      // Contract: server replies error(extension.unsupported) → returns false.
      await _connectAndReady(
        adapter,
        fake,
        extensionKeys: [RealtimeProviderExtensions.voiceSelection],
      );
      final before = fake.sentBytes.length;

      final extFuture = adapter.applyProviderExtension(
        RealtimeProviderExtensions.voiceSelection,
        {RealtimeProviderExtensions.selectionKey: 'unknown-voice'},
      );

      final frame = _decodeFrame(fake, before);
      _injectError(
        fake,
        frame['messageId'] as String,
        'extension.unsupported',
      );

      final result = await extFuture;
      expect(result, isFalse);
    },
  );

  // ─── C10: capabilities guard ──────────────────────────────────────────────

  test(
    'C10: applyProviderExtension with key absent from capabilities → false, '
    'no round-trip',
    () async {
      // Contract: if the server-advertised capabilities do not include the key,
      // return false immediately without sending a wire message.
      await _connectAndReady(
        adapter,
        fake,
        extensionKeys: ['some.other.extension'], // voiceSelection NOT in list
      );
      final before = fake.sentBytes.length;

      final result = await adapter.applyProviderExtension(
        RealtimeProviderExtensions.voiceSelection,
        {RealtimeProviderExtensions.selectionKey: 'shimmer'},
      );

      expect(result, isFalse);
      expect(
        fake.sentBytes.length,
        before,
        reason: 'No frame should be sent when capability is absent',
      );
    },
  );

  // ─── C11: applyProviderExtension pre-connect buffering ────────────────────

  test(
    'C11: applyProviderExtension before session.ready is buffered; '
    'future resolves after post-ready ack/error',
    () async {
      // Contract: pre-connect call is buffered; future resolves after the
      // post-ready round-trip ack.
      final connectFuture = adapter.connect(_testConfig);
      await _pump();
      final beforeCount = fake.sentBytes.length; // 1: session.open only

      // Call BEFORE session.ready.
      final extFuture = adapter.applyProviderExtension(
        RealtimeProviderExtensions.voiceSelection,
        {RealtimeProviderExtensions.selectionKey: 'shimmer'},
      );

      // No frame yet.
      expect(fake.sentBytes.length, beforeCount);

      // Inject session.ready WITH the extension capability.
      _injectSessionReady(
        fake,
        extensionKeys: [RealtimeProviderExtensions.voiceSelection],
      );
      await _pump();
      await _pump();

      // session.extension.apply should have been sent now.
      expect(fake.sentBytes.length, greaterThan(beforeCount));
      final frame = _decodeFrame(fake, beforeCount);
      expect(frame['type'], 'session.extension.apply');

      _injectAck(fake, frame['messageId'] as String);
      await connectFuture;

      final result = await extFuture;
      expect(result, isTrue);
    },
  );

  // ─── C12: ack correlation ─────────────────────────────────────────────────

  test(
    'C12: two parallel requests resolved by their own replyTo',
    () async {
      // Contract: _pendingRequests maps each messageId independently; the wrong
      // ack must not resolve the wrong future.
      await _connectAndReady(adapter, fake);
      final before = fake.sentBytes.length;

      // Send two requests concurrently.
      final toolsFuture = adapter.registerTools([_tool1]);
      final instrFuture = adapter.setInstructions('Parallel test');

      expect(fake.sentBytes.length, before + 2,
          reason: 'Two frames should be sent');

      final toolsFrame = _decodeFrame(fake, before);
      final instrFrame = _decodeFrame(fake, before + 1);
      expect(toolsFrame['type'], 'tools.set');
      expect(instrFrame['type'], 'session.instructions.set');

      final toolsMsgId = toolsFrame['messageId'] as String;
      final instrMsgId = instrFrame['messageId'] as String;

      // Ack in reverse order — each must resolve its own future only.
      bool toolsCompleted = false;
      bool instrCompleted = false;
      unawaited(toolsFuture.then((_) => toolsCompleted = true));
      unawaited(instrFuture.then((_) => instrCompleted = true));

      _injectAck(fake, instrMsgId); // ack instructions first
      await _pump();
      expect(instrCompleted, isTrue);
      expect(toolsCompleted, isFalse,
          reason: 'tools future must not complete on instructions ack');

      _injectAck(fake, toolsMsgId); // now ack tools
      await _pump();
      expect(toolsCompleted, isTrue);
    },
  );

  // ─── C13: dispose cleans up pending completers ────────────────────────────

  test(
    'C13: dispose completes pending request completers with StateError',
    () async {
      // Contract: dispose must not leave dangling Futures; pending ack
      // completers are completed with a StateError.
      await _connectAndReady(adapter, fake);

      // Start a request but do NOT inject an ack.
      final toolsFuture = adapter.registerTools([_tool1]);

      // Attach error handler BEFORE calling dispose(); if we attach after,
      // Dart may report the error as unhandled to the Zone because the future
      // can be completed with an error during dispose() synchronously.
      Object? caughtError;
      final capturedFuture = toolsFuture.then((_) {}).catchError((Object e) {
        caughtError = e;
      });

      // Dispose — should cancel the pending completer.
      await adapter.dispose();
      await capturedFuture;

      expect(caughtError, isA<StateError>(),
          reason: 'Pending completers must be cancelled on dispose');
    },
  );

  // ─── C14: session.open audioTurnMode dynamic ──────────────────────────────

  test(
    'C14: session.open audioTurnMode reflects _audioTurnMode (manual)',
    () async {
      // Contract: audioTurnMode field in session.open comes from _audioTurnMode,
      // not a hardcoded 'voice_activity'.
      await adapter.setAudioTurnMode(RealtimeAudioTurnMode.manual);

      // Start connect; session.open is the first frame.
      final connectFuture = adapter.connect(_testConfig);
      await _pump();

      // Frame 0 is session.open — read audioTurnMode from the CBOR body.
      final decoded = cbor.decode(fake.sentBytes[0]) as CborMap;
      final bodyMap = decoded[CborString('body')] as CborMap;
      final audioTurnMode =
          (bodyMap[CborString('audioTurnMode')] as CborString).toString();
      expect(
        audioTurnMode,
        'manual',
        reason:
            'audioTurnMode must come from _audioTurnMode, not be hardcoded',
      );

      _injectSessionReady(fake);
      await connectFuture;
    },
  );
}
