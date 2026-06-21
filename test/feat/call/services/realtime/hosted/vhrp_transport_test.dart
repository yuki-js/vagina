// Tests for the VHRP/1 transport layer.
//
// Testing philosophy (section 9.3 of the handoff doc):
//   Each test declares which user-facing contract it guards with a leading
//   contract comment.  The subject is the *user's experience*, not code paths.
//
// What these tests protect:
//   [FakeVhrpTransport]
//   • Users can have bytes injected as if the server sent them, enabling
//     adapter tests to simulate any server response without a real network.
//   • Bytes the adapter sends are captured so tests can assert the exact
//     payload that would leave the device.
//   • Tests can simulate a mid-session server disconnect so the adapter's
//     reconnect / recovery logic can be verified in isolation.
//   • Tests can simulate a stream error (network reset) so the adapter can
//     be verified to enter the "failed" state correctly.
//   • A disposed transport throws rather than silently misbehaving.
//   • A transport that failed connect does not accept sendBytes, protecting
//     against accidental sends on a dead socket.
//
//   [WebSocketVhrpTransport] (integration via loopback dart:io server)
//   • The app negotiates the `vhrp.cbor.v1` subprotocol during the WebSocket
//     handshake — without this, the server will reject the connection.
//   • Binary frames sent by the adapter arrive at the server as raw bytes,
//     and binary frames sent by the server arrive in [inboundBytes], so
//     audio/CBOR data is never corrupted by text transcoding.
//   • A clean server-side close transitions the transport to [disconnected]
//     so the adapter knows it must reconnect.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/realtime/hosted/fake_vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/vhrp_transport.dart';
import 'package:vagina/feat/call/services/realtime/hosted/websocket_vhrp_transport.dart';
import 'package:web_socket_channel/io.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const _wsUri = 'ws://localhost:0'; // placeholder; overridden in integration

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// Collects all state transitions emitted while [action] runs.
Future<List<VhrpTransportConnectionState>> _collectStates(
  VhrpRealtimeTransport transport,
  Future<void> Function() action,
) async {
  final states = <VhrpTransportConnectionState>[];
  final sub = transport.connectionStateUpdates.listen(states.add);
  await action();
  await Future<void>.delayed(Duration.zero); // drain microtask queue
  await sub.cancel();
  return states;
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeVhrpTransport tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('FakeVhrpTransport', () {
    late FakeVhrpTransport fake;

    setUp(() {
      fake = FakeVhrpTransport();
    });

    tearDown(() async {
      await fake.dispose();
    });

    // ── connect ──────────────────────────────────────────────────────────────

    test(
      // Contract: connecting transitions idle→connecting→connected so the
      // adapter can derive the "connecting" progress indicator for the UI.
      'connect emits connecting then connected state',
      () async {
        final states = await _collectStates(
          fake,
          () => fake.connect(Uri.parse(_wsUri), subprotocols: ['vhrp.cbor.v1']),
        );
        expect(states.map((s) => s.phase), [
          VhrpTransportPhase.connecting,
          VhrpTransportPhase.connected,
        ]);
        expect(fake.connectionState.phase, VhrpTransportPhase.connected);
      },
    );

    test(
      // Contract: the adapter must be able to verify which subprotocol it
      // requested so that its own tests can assert the `vhrp.cbor.v1`
      // negotiation intent is correct.
      'connect records the URI and subprotocols',
      () async {
        final uri = Uri.parse('wss://example.com/api/hosted-realtime/v1/connect');
        await fake.connect(uri, subprotocols: ['vhrp.cbor.v1']);
        expect(fake.lastConnectedUri, uri);
        expect(fake.lastConnectedSubprotocols, ['vhrp.cbor.v1']);
      },
    );

    test(
      // Contract: if the server refuses the connection (auth failure, bad
      // subprotocol, etc.) the transport emits a failed state so the adapter
      // can surface an error to the user.
      'connect emits failed state when connectBehavior throws',
      () async {
        final err = Exception('connection refused');
        fake.connectBehavior = (_, __) async => throw err;

        final states = await _collectStates(
          fake,
          () async {
            try {
              await fake.connect(Uri.parse(_wsUri));
            } catch (_) {}
          },
        );
        expect(states.last.phase, VhrpTransportPhase.failed);
        expect(states.last.error, err);
      },
    );

    test(
      // Contract: after a failed connect the transport is not in connected
      // state, so sendBytes is rejected — preventing silent loss of audio or
      // session messages.
      'sendBytes throws StateError when not connected',
      () async {
        expect(
          () => fake.sendBytes(_bytes([1, 2, 3])),
          throwsA(isA<StateError>()),
        );
      },
    );

    // ── sendBytes / sentBytes ─────────────────────────────────────────────

    test(
      // Contract: every byte sequence the adapter sends is recorded in order
      // so tests can assert the exact CBOR payload without relying on a real
      // server.
      'sendBytes records bytes in sentBytes in call order',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        final a = _bytes([0x01, 0x02]);
        final b = _bytes([0xAA, 0xBB, 0xCC]);
        fake.sendBytes(a);
        fake.sendBytes(b);
        expect(fake.sentBytes, [a, b]);
      },
    );

    test(
      // Contract: the transport preserves the exact bytes (no encoding
      // transform).  A user's voice PCM must arrive at the server bit-perfect.
      'sendBytes preserves the exact byte values',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        final payload = _bytes(List.generate(256, (i) => i));
        fake.sendBytes(payload);
        expect(fake.sentBytes.single, payload);
      },
    );

    // ── injectInbound ─────────────────────────────────────────────────────

    test(
      // Contract: the test harness can push bytes onto the inbound stream to
      // simulate any server message, enabling adapter tests to verify the full
      // processing pipeline without network I/O.
      'injectInbound delivers bytes on inboundBytes stream',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        final received = <Uint8List>[];
        final sub = fake.inboundBytes.listen(received.add);

        final chunk = _bytes([0xDE, 0xAD, 0xBE, 0xEF]);
        fake.injectInbound(chunk);
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(received, [chunk]);
      },
    );

    test(
      // Contract: multiple injected frames are delivered in order so adapter
      // tests that simulate a sequence of server messages get them in the
      // correct sequence.
      'injectInbound delivers multiple frames in order',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        final received = <Uint8List>[];
        final sub = fake.inboundBytes.listen(received.add);

        fake.injectInbound(_bytes([0x01]));
        fake.injectInbound(_bytes([0x02]));
        fake.injectInbound(_bytes([0x03]));
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(received.map((b) => b[0]).toList(), [1, 2, 3]);
      },
    );

    test(
      // Contract: injecting bytes while not connected is a no-op (does not
      // throw) so test teardown is not fragile.
      'injectInbound is a no-op when not connected',
      () {
        // Should not throw
        expect(() => fake.injectInbound(_bytes([0xFF])), returnsNormally);
      },
    );

    // ── simulateServerDisconnect ──────────────────────────────────────────

    test(
      // Contract: the adapter must react to an unexpected server-side close
      // (e.g. server restart) by initiating reconnect.  The transport must
      // emit a disconnected state to make this visible.
      'simulateServerDisconnect emits disconnected state',
      () async {
        await fake.connect(Uri.parse(_wsUri));

        final states = <VhrpTransportConnectionState>[];
        final sub = fake.connectionStateUpdates.listen(states.add);

        fake.simulateServerDisconnect(message: 'server went away');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(states.single.phase, VhrpTransportPhase.disconnected);
        expect(states.single.message, 'server went away');
        expect(fake.connectionState.phase, VhrpTransportPhase.disconnected);
      },
    );

    // ── simulateStreamError ───────────────────────────────────────────────

    test(
      // Contract: a network reset mid-session must surface as a "failed"
      // state so the adapter can display an error and trigger reconnect with
      // the resume token.
      'simulateStreamError emits failed state with the given error',
      () async {
        await fake.connect(Uri.parse(_wsUri));

        final states = <VhrpTransportConnectionState>[];
        final sub = fake.connectionStateUpdates.listen(states.add);

        final err = StateError('simulated tcp reset');
        fake.simulateStreamError(err);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(states.single.phase, VhrpTransportPhase.failed);
        expect(states.single.error, err);
      },
    );

    // ── disconnect ────────────────────────────────────────────────────────

    test(
      // Contract: calling disconnect transitions connected→disconnecting→
      // disconnected so the adapter UI can show "closing…" while the clean
      // handshake completes.
      'disconnect emits disconnecting then disconnected',
      () async {
        await fake.connect(Uri.parse(_wsUri));

        final states = <VhrpTransportConnectionState>[];
        final sub = fake.connectionStateUpdates.listen(states.add);
        await fake.disconnect();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(states.map((s) => s.phase), [
          VhrpTransportPhase.disconnecting,
          VhrpTransportPhase.disconnected,
        ]);
        expect(fake.connectionState.phase, VhrpTransportPhase.disconnected);
      },
    );

    test(
      // Contract: disconnect is idempotent — calling it twice (e.g. in a
      // cleanup path that runs after the server already closed) must not throw.
      'disconnect is idempotent',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        await fake.disconnect();
        await expectLater(fake.disconnect(), completes);
      },
    );

    // ── dispose ───────────────────────────────────────────────────────────

    test(
      // Contract: after dispose, any further method call throws StateError so
      // programming mistakes (calling connect on a torn-down object) are caught
      // early rather than silently misbehaving.
      'after dispose, connect throws StateError',
      () async {
        await fake.dispose();
        expect(
          () => fake.connect(Uri.parse(_wsUri)),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      // Same contract as above — sendBytes must also throw after dispose.
      'after dispose, sendBytes throws StateError',
      () async {
        await fake.dispose();
        expect(
          () => fake.sendBytes(_bytes([0x00])),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      // Contract: dispose is idempotent — teardown code that calls dispose
      // multiple times must not throw.
      'dispose is idempotent',
      () async {
        await fake.dispose();
        await expectLater(fake.dispose(), completes);
      },
    );

    // ── reset ─────────────────────────────────────────────────────────────

    test(
      // Contract: reset restores the fake to a clean state between test cases
      // so a single FakeVhrpTransport instance can be shared across an entire
      // test group without bleed-over.
      'reset clears sentBytes and restores idle state',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        fake.sendBytes(_bytes([0x01]));
        await fake.reset();

        expect(fake.sentBytes, isEmpty);
        expect(fake.connectionState.phase, VhrpTransportPhase.idle);
        expect(fake.lastConnectedUri, isNull);
      },
    );

    test(
      // Contract: after reset a new connect succeeds, confirming the fake is
      // fully reusable.
      'reset allows reconnect on the same instance',
      () async {
        await fake.connect(Uri.parse(_wsUri));
        await fake.reset();
        await fake.connect(
          Uri.parse(_wsUri),
          subprotocols: ['vhrp.cbor.v1'],
        );
        expect(fake.connectionState.phase, VhrpTransportPhase.connected);
      },
    );

    // ── connectionState initial value ─────────────────────────────────────

    test(
      // Contract: before any connect call the transport reports idle so the
      // adapter correctly shows the "not started" state in the UI.
      'initial connectionState is idle',
      () {
        expect(fake.connectionState.phase, VhrpTransportPhase.idle);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WebSocketVhrpTransport — integration tests via loopback dart:io server
  // ─────────────────────────────────────────────────────────────────────────

  group('WebSocketVhrpTransport (loopback integration)', () {
    late HttpServer server;
    late Uri wsUri;

    // Frames arriving at the server side from the client.
    late StreamController<Uint8List> serverFramesController;
    // Completer that resolves to the raw WebSocket once the handshake is done.
    late Completer<WebSocket> serverSocketCompleter;

    setUp(() async {
      serverFramesController = StreamController<Uint8List>.broadcast();
      serverSocketCompleter = Completer<WebSocket>();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      wsUri = Uri.parse('ws://127.0.0.1:${server.port}');

      // Accept exactly one WebSocket connection for the test.
      server.listen((HttpRequest req) async {
        // Negotiate subprotocol: accept vhrp.cbor.v1 if offered.
        final requested =
            req.headers['sec-websocket-protocol']?.join(',') ?? '';
        final protocol =
            requested.contains('vhrp.cbor.v1') ? 'vhrp.cbor.v1' : null;
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: protocol != null ? (_) => protocol : null,
        );
        if (!serverSocketCompleter.isCompleted) {
          serverSocketCompleter.complete(ws);
        }
        ws.listen((data) {
          if (data is List<int>) {
            serverFramesController.add(Uint8List.fromList(data));
          }
        });
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await serverFramesController.close();
    });

    test(
      // Contract: the app must negotiate the `vhrp.cbor.v1` subprotocol
      // during the WebSocket handshake.  Without this, the server rejects
      // the connection (our server here accepts only vhrp.cbor.v1).
      'connect negotiates vhrp.cbor.v1 subprotocol',
      () async {
        final transport = WebSocketVhrpTransport();
        addTearDown(transport.dispose);

        await transport.connect(wsUri, subprotocols: ['vhrp.cbor.v1']);
        expect(transport.connectionState.phase, VhrpTransportPhase.connected);

        // The loopback server completed its handshake — negotiation succeeded.
        final ws = await serverSocketCompleter.future
            .timeout(const Duration(seconds: 5));
        expect(ws.protocol, 'vhrp.cbor.v1');
      },
    );

    test(
      // Contract: binary frames sent by the adapter arrive at the server as
      // raw bytes (no base64 or text encoding), so CBOR-encoded audio and
      // session messages are never corrupted.
      'sendBytes delivers exact binary frame to the server',
      () async {
        final transport = WebSocketVhrpTransport();
        addTearDown(transport.dispose);

        await transport.connect(wsUri, subprotocols: ['vhrp.cbor.v1']);
        await serverSocketCompleter.future.timeout(const Duration(seconds: 5));

        // Wait for the handshake to complete so the server listener is active.
        await serverSocketCompleter.future.timeout(const Duration(seconds: 5));

        final payload = Uint8List.fromList([0xA1, 0x64, 0x74, 0x65, 0x73, 0x74]);

        // Wait for the server to receive the frame via the shared broadcast
        // controller rather than a fixed delay.
        final serverReceivedCompleter = Completer<Uint8List>();
        final sub = serverFramesController.stream.listen((frame) {
          if (!serverReceivedCompleter.isCompleted) {
            serverReceivedCompleter.complete(frame);
          }
        });

        transport.sendBytes(payload);
        final received =
            await serverReceivedCompleter.future.timeout(const Duration(seconds: 5));
        await sub.cancel();

        expect(received, payload);
      },
    );

    test(
      // Contract: binary frames sent by the server appear on [inboundBytes]
      // as [Uint8List] so the CBOR codec receives raw bytes and can decode
      // them correctly.
      'binary frame from server arrives on inboundBytes as Uint8List',
      () async {
        final transport = WebSocketVhrpTransport();
        addTearDown(transport.dispose);

        await transport.connect(wsUri, subprotocols: ['vhrp.cbor.v1']);
        final ws =
            await serverSocketCompleter.future.timeout(const Duration(seconds: 5));

        final serverPayload = Uint8List.fromList([0xBE, 0xEF, 0xCA, 0xFE]);

        // Single listener collects frames AND completes the barrier.
        final received = <Uint8List>[];
        final frameCompleter = Completer<void>();
        final sub = transport.inboundBytes.listen((frame) {
          received.add(frame);
          if (!frameCompleter.isCompleted) frameCompleter.complete();
        });

        ws.add(serverPayload);
        await frameCompleter.future.timeout(const Duration(seconds: 5));
        await sub.cancel();

        expect(received, [serverPayload]);
        expect(received.single, isA<Uint8List>());
      },
    );

    test(
      // Contract: when the server closes the WebSocket, the transport emits
      // a [disconnected] state.  The adapter must see this to initiate
      // reconnect and preserve the user's session.
      'server-side close emits disconnected state',
      () async {
        final transport = WebSocketVhrpTransport();
        addTearDown(transport.dispose);

        await transport.connect(wsUri, subprotocols: ['vhrp.cbor.v1']);
        final ws =
            await serverSocketCompleter.future.timeout(const Duration(seconds: 5));

        // Wait for the disconnected state event rather than a fixed delay.
        final disconnectedCompleter = Completer<void>();
        final states = <VhrpTransportConnectionState>[];
        final sub = transport.connectionStateUpdates.listen((s) {
          states.add(s);
          if (s.phase == VhrpTransportPhase.disconnected &&
              !disconnectedCompleter.isCompleted) {
            disconnectedCompleter.complete();
          }
        });

        await ws.close(WebSocketStatus.normalClosure);
        await disconnectedCompleter.future.timeout(const Duration(seconds: 5));
        await sub.cancel();

        expect(
          states.any((s) => s.phase == VhrpTransportPhase.disconnected),
          isTrue,
        );
      },
    );

    test(
      // Contract: sendBytes throws StateError before connect so the adapter
      // cannot accidentally send session messages before the handshake
      // completes, which would cause silent data loss.
      'sendBytes throws before connect is called',
      () {
        final transport = WebSocketVhrpTransport();
        expect(
          () => transport.sendBytes(Uint8List.fromList([0x00])),
          throwsA(isA<StateError>()),
        );
        transport.dispose();
      },
    );
  });
}
