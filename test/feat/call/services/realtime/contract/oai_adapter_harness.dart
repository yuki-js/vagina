// OAI (standalone) AdapterHarness — drives OaiRealtimeAdapter using
// FakeOaiTransport (injects OAI-native JSON events into the binding layer).
//
// This file is part of the shared contract test suite:
//   contract/realtime_adapter_contract.dart  ← shared tests
//   THIS FILE                                ← OAI harness
//   vhrp/vhrp_realtime_adapter_contract_test.dart ← VHRP harness + test entry
//
// OAI injection sequence notes:
//   • The OAI adapter does NOT add optimistic items; items appear in the thread
//     only when the server sends conversation.item.created or response.*
//     events.  The harness therefore injects those events explicitly.
//   • sendText() causes two sendJson calls (conversation.item.create +
//     response.create) that are captured in FakeOaiTransport.sentMessages
//     but the harness does not need to inspect them — it only injects the
//     server-side responses.

import 'dart:async';

import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/fake_oai_transport.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_binding.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';

import '../contract/realtime_adapter_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OAI harness
// ─────────────────────────────────────────────────────────────────────────────

final class OaiAdapterHarness implements AdapterHarness {
  late FakeOaiTransport _fake;
  late OaiRealtimeClient _client;
  late OaiRealtimeAdapter _adapter;

  static final _testConfig = SelfhostedVoiceAgentApiConfig(
    providerType: VoiceAgentProviderType.openai,
    baseUrl: 'https://fake.openai.test',
    apiKey: 'sk-contract-test',
  );

  @override
  RealtimeAdapter get adapter => _adapter;

  @override
  Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

  @override
  Future<void> setUp() async {
    _fake = FakeOaiTransport();
    _client = OaiRealtimeClient(transport: _fake);
    _adapter = OaiRealtimeAdapter(client: _client);
  }

  @override
  Future<void> tearDown() async {
    await _adapter.dispose();
    // FakeOaiTransport is disposed through the client/adapter chain; also
    // call it directly to ensure streams are closed.
    if (!_fake.connectionState.isTerminal) {
      await _fake.dispose();
    }
  }

  @override
  Future<void> connect() async {
    // connect() on OaiRealtimeAdapter calls _client.connect() and then
    // updateSession().  Both complete immediately with FakeOaiTransport
    // because sendJson() is a sync no-op and connect() just emits states.
    await _adapter.connect(_testConfig);
    // connectionState is now connected because FakeOaiTransport emitted
    // the connected state during its connect() call.
  }

  @override
  Future<void> simulateAssistantTextReply({
    required String userItemId,
    required String assistantItemId,
    required String responseText,
  }) async {
    // 1. Server echoes the user item as created + completed.
    _fake.injectInbound({
      'type': 'conversation.item.created',
      'item': {
        'id': userItemId,
        'object': 'realtime.item',
        'type': 'message',
        'role': 'user',
        'status': 'completed',
        'content': [
          {'type': 'input_text', 'text': 'sent text'},
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);

    // 2. Server begins assistant response item.
    _fake.injectInbound({
      'type': 'response.output_item.added',
      'response_id': 'resp-oai-001',
      'output_index': 0,
      'item': {
        'id': assistantItemId,
        'object': 'realtime.item',
        'type': 'message',
        'role': 'assistant',
        'status': 'in_progress',
        'content': [],
      },
    });
    await Future<void>.delayed(Duration.zero);

    // 3. Content part opened.
    _fake.injectInbound({
      'type': 'response.content_part.added',
      'response_id': 'resp-oai-001',
      'item_id': assistantItemId,
      'output_index': 0,
      'content_index': 0,
      'part': {'type': 'text', 'text': ''},
    });
    await Future<void>.delayed(Duration.zero);

    // 4. Text delta streamed.
    _fake.injectInbound({
      'type': 'response.output_text.delta',
      'response_id': 'resp-oai-001',
      'item_id': assistantItemId,
      'output_index': 0,
      'content_index': 0,
      'delta': responseText,
    });
    await Future<void>.delayed(Duration.zero);

    // 5. Text finalised.
    _fake.injectInbound({
      'type': 'response.output_text.done',
      'response_id': 'resp-oai-001',
      'item_id': assistantItemId,
      'output_index': 0,
      'content_index': 0,
      'text': responseText,
    });
    await Future<void>.delayed(Duration.zero);

    // 6. Assistant item completed.
    _fake.injectInbound({
      'type': 'response.output_item.done',
      'response_id': 'resp-oai-001',
      'output_index': 0,
      'item': {
        'id': assistantItemId,
        'object': 'realtime.item',
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'content': [
          {'type': 'text', 'text': responseText},
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
    // 1. Server begins a function_call output item.
    _fake.injectInbound({
      'type': 'response.output_item.added',
      'response_id': 'resp-oai-fc-001',
      'output_index': 0,
      'item': {
        'id': functionCallItemId,
        'object': 'realtime.item',
        'type': 'function_call',
        'role': 'assistant',
        'status': 'in_progress',
        'call_id': callId,
        'name': functionName,
        'content': [],
      },
    });
    await Future<void>.delayed(Duration.zero);

    // 2. Arguments delta (simulate streaming, even if one chunk).
    _fake.injectInbound({
      'type': 'response.function_call_arguments.delta',
      'response_id': 'resp-oai-fc-001',
      'item_id': functionCallItemId,
      'output_index': 0,
      'call_id': callId,
      'delta': arguments,
    });
    await Future<void>.delayed(Duration.zero);

    // 3. Arguments finalised.
    _fake.injectInbound({
      'type': 'response.function_call_arguments.done',
      'response_id': 'resp-oai-fc-001',
      'item_id': functionCallItemId,
      'output_index': 0,
      'call_id': callId,
      'name': functionName,
      'arguments': arguments,
    });
    await Future<void>.delayed(Duration.zero);

    // 4. Function call item completed.
    _fake.injectInbound({
      'type': 'response.output_item.done',
      'response_id': 'resp-oai-fc-001',
      'output_index': 0,
      'item': {
        'id': functionCallItemId,
        'object': 'realtime.item',
        'type': 'function_call',
        'role': 'assistant',
        'status': 'completed',
        'call_id': callId,
        'name': functionName,
        'arguments': arguments,
        'content': [],
      },
    });
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> drainAfterInterrupt() async {
    // OAI: interrupt() calls _client.cancelResponse() which sendJsons a
    // response.cancel; FakeOaiTransport records it but emits no events.
    // Just drain microtasks.
    await Future<void>.delayed(Duration.zero);
  }
}
