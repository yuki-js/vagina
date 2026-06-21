// VHRP (hosted) AdapterHarness — drives VhrpRealtimeAdapter using
// FakeVhrpTransport and CBOR-encoded S2C messages.
//
// This file is part of the shared contract test suite:
//   contract/realtime_adapter_contract.dart  ← shared tests
//   THIS FILE                                ← VHRP harness
//   oai/oai_realtime_adapter_contract_test.dart ← OAI harness + test entry
//
// Design notes:
//   • FakeVhrpTransport is injected so no real WebSocket is needed.
//   • All S2C messages are CBOR-encoded and pushed via injectInbound().
//   • The harness synthesises realistic VHRP S2C message sequences so the
//     same contracts can be asserted as for the OAI harness.

import 'dart:async';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';

import '../contract/realtime_adapter_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CBOR helpers (shared with existing tests in hosted/)
// ─────────────────────────────────────────────────────────────────────────────

Uint8List _encodeCbor(Map<String, Object?> dart) {
  return Uint8List.fromList(cbor.encode(_dartToCbor(dart)));
}

CborValue _dartToCbor(Object? value) {
  return switch (value) {
    null => const CborNull(),
    bool v => CborBool(v),
    int v => CborSmallInt(v),
    double v => CborFloat(v),
    String v => CborString(v),
    Uint8List v => CborBytes(v),
    Map<String, Object?> v => CborMap({
        for (final e in v.entries) CborString(e.key): _dartToCbor(e.value),
      }),
    List<Object?> v => CborList(v.map(_dartToCbor).toList()),
    _ => CborString(value.toString()),
  };
}

void _injectCbor(FakeVhrpTransport fake, Map<String, Object?> msg) {
  fake.injectInbound(_encodeCbor(msg));
}

// ─────────────────────────────────────────────────────────────────────────────
// VHRP harness
// ─────────────────────────────────────────────────────────────────────────────

final class VhrpAdapterHarness implements AdapterHarness {
  late FakeVhrpTransport _fake;
  late VhrpRealtimeAdapter _adapter;

  static const _testToken = 'vhrp-contract-test-jwt';
  static const _testModelId = 'contract-test-model';
  static final _testConfig =
      HostedVoiceAgentApiConfig(modelId: _testModelId);

  @override
  RealtimeAdapter get adapter => _adapter;

  @override
  Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

  @override
  Future<void> setUp() async {
    _fake = FakeVhrpTransport();
    _adapter = VhrpRealtimeAdapter(
      transport: _fake,
      tokenProvider: () async => _testToken,
      urlResolver: (_) =>
          Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
    );
  }

  @override
  Future<void> tearDown() async {
    await _adapter.dispose();
    await _fake.dispose();
  }

  @override
  Future<void> connect() async {
    final connectFuture = _adapter.connect(_testConfig);
    // Yield one event-loop turn so connect() reaches its session-ready wait.
    await Future<void>.delayed(Duration.zero);
    // Inject session.ready → adapter transitions to connected.
    _injectCbor(_fake, {
      'type': 'session.ready',
      'body': {
        'sessionId': 'vhrp-srv-session-001',
        'threadId': 'vhrp-srv-thread-001',
        'conversationId': 'vhrp-srv-conv-001',
        'capabilities': {
          'extensions': <Object?>[],
        },
      },
    });
    await connectFuture;
  }

  @override
  Future<void> simulateAssistantTextReply({
    required String userItemId,
    required String assistantItemId,
    required String responseText,
  }) async {
    // 1. Server echoes the user message item as completed.
    _injectCbor(_fake, {
      'type': 'thread.patch',
      'body': {
        'ops': [
          {
            'op': 'add_item',
            'item': {
              'id': userItemId,
              'type': 'message',
              'role': 'user',
              'status': 'in_progress',
              'content': <Object?>[],
            },
          },
          {'op': 'put_part', 'itemId': userItemId, 'contentIndex': 0, 'part': {'type': 'text', 'isDone': false}},
          {'op': 'append_text', 'itemId': userItemId, 'contentIndex': 0, 'delta': 'sent text'},
          {'op': 'set_status', 'itemId': userItemId, 'status': 'completed'},
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);

    // 2. Server begins streaming the assistant response.
    _injectCbor(_fake, {
      'type': 'thread.patch',
      'body': {
        'ops': [
          {
            'op': 'add_item',
            'item': {
              'id': assistantItemId,
              'type': 'message',
              'role': 'assistant',
              'status': 'in_progress',
              'content': <Object?>[],
            },
          },
          {
            'op': 'put_part',
            'itemId': assistantItemId,
            'contentIndex': 0,
            'part': {'type': 'text', 'isDone': false},
          },
          {
            'op': 'append_text',
            'itemId': assistantItemId,
            'contentIndex': 0,
            'delta': responseText,
          },
          {
            'op': 'set_status',
            'itemId': assistantItemId,
            'status': 'completed',
          },
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> simulateFunctionCallRequest({
    required String functionCallItemId,
    required String callId,
    required String functionName,
    required String arguments,
  }) async {
    _injectCbor(_fake, {
      'type': 'thread.patch',
      'body': {
        'ops': [
          {
            'op': 'add_item',
            'item': {
              'id': functionCallItemId,
              // Projector maps 'function_call' → RealtimeThreadItemType.functionCall
              'type': 'function_call',
              'role': 'assistant',
              'status': 'in_progress',
              'content': <Object?>[],
            },
          },
          {
            'op': 'set_field',
            'itemId': functionCallItemId,
            'field': 'callId',
            'value': callId,
          },
          {
            'op': 'set_field',
            'itemId': functionCallItemId,
            'field': 'name',
            'value': functionName,
          },
          {
            'op': 'set_field',
            'itemId': functionCallItemId,
            'field': 'arguments',
            'value': arguments,
          },
          {
            'op': 'set_status',
            'itemId': functionCallItemId,
            'status': 'completed',
          },
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> drainAfterInterrupt() async {
    // For VHRP, interrupt() is fire-and-forget on the wire; just drain
    // microtasks so state listeners settle.
    await Future<void>.delayed(Duration.zero);
  }
}
