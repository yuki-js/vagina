// Tests for VhrpRealtimeAdapter — Step 3: minimal connection.
//
// Contract assertions (handoff doc §9.3):
//   C1: connect() sends session.open with correct type / modelId / token /
//       audio format over the transport as CBOR.
//   C2: When fake injects session.ready, connectionState becomes connected
//       and the update fires on connectionStateUpdates.
//   C3: When tokenProvider returns null, connect() throws StateError, emits
//       an error on errors stream, and connectionState is failed.
//   C4: When fake injects error(recoverable:false) before session.ready,
//       connectionState becomes failed and the error appears on errors stream.
//   C5: dispose() is idempotent — calling it twice does not throw.
//   C6: session.open body carries the modelId, token, voice, instructions,
//       audioTurnMode = voice_activity, encoding = pcm_s16le, sampleRate = 24000,
//       channels = 1.

import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

const String _testToken = 'test-jwt-token-abc123';
const String _testModelId = 'vagina-v1-turbo';

final _testConfig = HostedVoiceAgentApiConfig(modelId: _testModelId);

/// Builds a [VhrpRealtimeAdapter] with the given [fake] transport and an
/// optional [token] (defaults to [_testToken]).  The [urlResolver] bypasses
/// AppConfig so tests never hit real network.
VhrpRealtimeAdapter _makeAdapter(
  FakeVhrpTransport fake, {
  String? token = _testToken,
  Uri Function(bool)? urlResolver,
}) {
  return VhrpRealtimeAdapter(
    transport: fake,
    tokenProvider: () async => token,
    urlResolver: urlResolver ??
        (_) => Uri.parse('ws://localhost:0/api/hosted-realtime/v1/connect'),
  );
}

/// Decodes the first bytes in [fake.sentBytes] as a CBOR map and returns it
/// as a Dart map for assertions.
Map<String, Object?> _decodeSentEnvelope(FakeVhrpTransport fake) {
  expect(fake.sentBytes, isNotEmpty, reason: 'No bytes were sent');
  final decoded = cbor.decode(fake.sentBytes.first);
  expect(decoded, isA<CborMap>(), reason: 'Sent frame must be a CBOR map');
  final map = decoded as CborMap;
  final result = <String, Object?>{};
  for (final entry in map.entries) {
    final key = entry.key;
    if (key is CborString) {
      result[key.toString()] = _cborToValue(entry.value);
    }
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
          if (e.key is CborString) (e.key as CborString).toString(): _cborToValue(e.value),
      },
    CborList l => [for (final e in l) _cborToValue(e)],
    _ => null,
  };
}

/// Encodes and injects a [SessionReadyMsg] into [fake] as if the server sent it.
void _injectSessionReady(FakeVhrpTransport fake) {
  // session.ready is S2C — build the raw CBOR envelope directly.
  final map = CborMap({
    CborString('type'): CborString('session.ready'),
    CborString('replyTo'): CborString('session-open-msg-id'),
    CborString('body'): CborMap({
      CborString('sessionId'): CborString('srv-session-001'),
      CborString('threadId'): CborString('srv-thread-001'),
      CborString('conversationId'): CborString('srv-conv-001'),
      CborString('capabilities'): CborMap({
        CborString('extensions'): CborList([]),
      }),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

/// Encodes and injects an [ErrorMsg] (non-recoverable) into [fake].
void _injectNonRecoverableError(FakeVhrpTransport fake) {
  final map = CborMap({
    CborString('type'): CborString('error'),
    CborString('body'): CborMap({
      CborString('code'): CborString('auth.invalid_jwt'),
      CborString('message'): CborString('JWT validation failed.'),
      CborString('recoverable'): CborBool(false),
    }),
  });
  fake.injectInbound(Uint8List.fromList(cbor.encode(map)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late FakeVhrpTransport fake;

  setUp(() {
    fake = FakeVhrpTransport();
  });

  tearDown(() async {
    await fake.dispose();
  });

  // ── C1 / C6: session.open is CBOR-encoded with correct fields ───────────────

  group('C1+C6 — session.open wire contract', () {
    test(
      'connect() sends a CBOR session.open frame with correct type, '
      'modelId, token, audioTurnMode, and audio format',
      () async {
        // Contract: the very first byte sequence written to the transport must
        // be a CBOR map with type=session.open, modelId, token,
        // audioTurnMode=voice_activity, inputAudio/outputAudio with
        // encoding=pcm_s16le, sampleRate=24000, channels=1.
        final adapter = _makeAdapter(fake);

        // Start connect and immediately inject session.ready so the future
        // can complete.
        await adapter.setInstructions('Be concise.');
        final connectFuture = adapter.connect(
          _testConfig,
          voice: 'coral',
        );

        // Yield to let connect() reach its suspension point on _sessionReadyCompleter.
        await Future<void>.delayed(Duration.zero);
        _injectSessionReady(fake);

        await connectFuture;

        final env = _decodeSentEnvelope(fake);
        expect(env['type'], equals('session.open'), reason: 'C1: type mismatch');

        final body = env['body'] as Map<String, Object?>;
        expect(body['token'], equals(_testToken), reason: 'C6: token');
        expect(body['modelId'], equals(_testModelId), reason: 'C6: modelId');
        expect(body['voice'], equals('coral'), reason: 'C6: voice');
        expect(body['instructions'], equals('Be concise.'),
            reason: 'C6: instructions');
        expect(body['audioTurnMode'], equals('voice_activity'),
            reason: 'C6: audioTurnMode');

        final inputAudio = body['inputAudio'] as Map<String, Object?>;
        expect(inputAudio['encoding'], equals('pcm_s16le'),
            reason: 'C6: inputAudio.encoding');
        expect(inputAudio['sampleRate'], equals(24000),
            reason: 'C6: inputAudio.sampleRate');
        expect(inputAudio['channels'], equals(1),
            reason: 'C6: inputAudio.channels');

        final outputAudio = body['outputAudio'] as Map<String, Object?>;
        expect(outputAudio['encoding'], equals('pcm_s16le'),
            reason: 'C6: outputAudio.encoding');
        expect(outputAudio['sampleRate'], equals(24000),
            reason: 'C6: outputAudio.sampleRate');
        expect(outputAudio['channels'], equals(1),
            reason: 'C6: outputAudio.channels');

        await adapter.dispose();
      },
    );

    test(
      'session.open connects to the correct subprotocol vhrp.cbor.v1',
      () async {
        // Contract: the transport must be asked for subprotocol vhrp.cbor.v1
        // so the server selects the CBOR framing.
        final adapter = _makeAdapter(fake);

        final connectFuture = adapter.connect(_testConfig);
        await Future<void>.delayed(Duration.zero);
        _injectSessionReady(fake);
        await connectFuture;

        expect(
          fake.lastConnectedSubprotocols,
          contains('vhrp.cbor.v1'),
          reason: 'Transport must negotiate vhrp.cbor.v1',
        );

        await adapter.dispose();
      },
    );
  });

  // ── C2: session.ready → connectionState.connected ───────────────────────────

  group('C2 — session.ready → connected', () {
    test(
      'connectionState becomes connected after session.ready is injected',
      () async {
        // Contract: once session.ready is received, connectionState must be
        // connected and a connected update must appear on connectionStateUpdates.
        final adapter = _makeAdapter(fake);

        final states = <RealtimeAdapterConnectionPhase>[];
        final sub =
            adapter.connectionStateUpdates.listen((s) => states.add(s.phase));

        final connectFuture = adapter.connect(_testConfig);
        await Future<void>.delayed(Duration.zero);
        _injectSessionReady(fake);
        await connectFuture;

        expect(adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.connected));
        expect(states, contains(RealtimeAdapterConnectionPhase.connected));

        await sub.cancel();
        await adapter.dispose();
      },
    );

    test(
      'connectionStateUpdates emits connecting before connected',
      () async {
        // Contract: the adapter must signal connecting before connected so
        // UI can show a spinner.
        final adapter = _makeAdapter(fake);

        final phases = <RealtimeAdapterConnectionPhase>[];
        final sub =
            adapter.connectionStateUpdates.listen((s) => phases.add(s.phase));

        final connectFuture = adapter.connect(_testConfig);
        await Future<void>.delayed(Duration.zero);
        _injectSessionReady(fake);
        await connectFuture;

        final connectingIndex =
            phases.indexOf(RealtimeAdapterConnectionPhase.connecting);
        final connectedIndex =
            phases.indexOf(RealtimeAdapterConnectionPhase.connected);

        expect(connectingIndex, greaterThanOrEqualTo(0),
            reason: 'connecting must appear');
        expect(connectedIndex, greaterThanOrEqualTo(0),
            reason: 'connected must appear');
        expect(connectingIndex, lessThan(connectedIndex),
            reason: 'connecting must precede connected');

        await sub.cancel();
        await adapter.dispose();
      },
    );
  });

  // ── C3: tokenProvider returns null ──────────────────────────────────────────

  group('C3 — null token handling', () {
    test(
      'connect() throws StateError and emits error when tokenProvider '
      'returns null',
      () async {
        // Contract: if no JWT is available, connect() must fail immediately
        // (before touching the transport) by throwing StateError and emitting
        // a RealtimeAdapterError with code auth.missing_token.
        final adapter = _makeAdapter(fake, token: null);

        final errors = <RealtimeAdapterError>[];
        final sub = adapter.errors.listen(errors.add);

        await expectLater(
          () => adapter.connect(_testConfig),
          throwsA(isA<StateError>()),
        );

        // Allow microtasks to flush.
        await Future<void>.microtask(() {});

        expect(errors, hasLength(1));
        expect(errors.first.code, equals('auth.missing_token'));
        expect(adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.failed));

        // The transport must NOT have been connected (no token → no connection).
        expect(fake.lastConnectedUri, isNull,
            reason: 'transport.connect must not be called when token is null');

        await sub.cancel();
        await adapter.dispose();
      },
    );
  });

  // ── C4: error(recoverable:false) → failed ───────────────────────────────────

  group('C4 — non-recoverable error during session establishment', () {
    test(
      'connectionState becomes failed and errors stream fires when '
      'non-recoverable error is received before session.ready',
      () async {
        // Contract: if the server rejects the session.open with a non-
        // recoverable error, the adapter must transition to failed and emit
        // the error on the errors stream.
        final adapter = _makeAdapter(fake);

        final errors = <RealtimeAdapterError>[];
        final errorSub = adapter.errors.listen(errors.add);

        final connectFuture = adapter.connect(_testConfig);

        // Give connect() time to send session.open then reach the wait.
        await Future<void>.delayed(Duration.zero);

        // Simulate server rejecting the JWT.
        _injectNonRecoverableError(fake);

        // connect() should throw because the session.ready completer is
        // failed.
        await expectLater(connectFuture, throwsA(isA<Exception>()));

        expect(adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.failed));
        expect(errors, hasLength(1));
        expect(errors.first.code, equals('auth.invalid_jwt'));

        await errorSub.cancel();
        await adapter.dispose();
      },
    );
  });

  // ── C5: dispose idempotency ─────────────────────────────────────────────────

  group('C5 — dispose is idempotent', () {
    test(
      'calling dispose() twice does not throw',
      () async {
        // Contract: dispose() must be safe to call multiple times, matching
        // the RealtimeAdapter interface contract.
        final adapter = _makeAdapter(fake);
        await adapter.dispose();
        await expectLater(adapter.dispose(), completes);
      },
    );

    test(
      'calling dispose() on a connected adapter cleans up correctly',
      () async {
        // Contract: dispose() on an active session must not leak resources.
        final adapter = _makeAdapter(fake);

        final connectFuture = adapter.connect(_testConfig);
        await Future<void>.delayed(Duration.zero);
        _injectSessionReady(fake);
        await connectFuture;

        await expectLater(adapter.dispose(), completes);
        // Second dispose must also not throw.
        await expectLater(adapter.dispose(), completes);
      },
    );
  });

  // ── Additional: wrong config type ────────────────────────────────────────────

  group('wrong config type handling', () {
    test(
      'connect() throws ArgumentError and emits error when given a '
      'non-HostedVoiceAgentApiConfig',
      () async {
        // Contract: VhrpRealtimeAdapter is exclusively for hosted sessions.
        // Passing any other config type must fail fast with an ArgumentError.
        final adapter = _makeAdapter(fake);

        final errors = <RealtimeAdapterError>[];
        final sub = adapter.errors.listen(errors.add);

        final wrongConfig = SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.openai,
          baseUrl: 'https://api.openai.com',
          apiKey: 'sk-test',
        );

        await expectLater(
          () => adapter.connect(wrongConfig),
          throwsA(isA<ArgumentError>()),
        );

        await Future<void>.microtask(() {});

        expect(errors, hasLength(1));
        expect(errors.first.code, equals('adapter.wrong_config_type'));
        expect(adapter.connectionState.phase,
            equals(RealtimeAdapterConnectionPhase.failed));

        await sub.cancel();
        await adapter.dispose();
      },
    );
  });
}
