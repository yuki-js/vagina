/// Native platform abstraction for sandbox spawning
///
/// Provides platform-specific types and spawn function for Native (dart:isolate)
library sandbox_platform;

import 'dart:async';
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

/// Platform-specific ReceivePort type
typedef PlatformReceivePort = ReceivePort;

/// Platform-specific SendPort type (for internal use, different from ReplyToPort)
typedef PlatformSendPort = SendPort;

/// Platform-specific Isolate handle type
typedef PlatformIsolate = Isolate;

/// Spawn a worker on Native platform
///
/// Spawns a real Dart Isolate running the given entrypoint.
///
/// Returns: (isolate handle, host receive port, worker send port from handshake)
Future<(PlatformIsolate, PlatformReceivePort, PlatformSendPort)> spawnPlatformWorker(
  void Function(SendPort) entryPoint,
  Duration timeout,
) async {
  // Create receive port for host-side listening
  final receivePort = ReceivePort();

  // Spawn the isolate worker
  final isolate = await Isolate.spawn(
    entryPoint,
    receivePort.sendPort,
  );

  // Wait for handshake response with isolate's SendPort
  final handshakeMessage = await receivePort.first.timeout(
    timeout,
    onTimeout: () {
      throw TimeoutException(
        'Handshake timeout: isolate did not respond within $timeout',
      );
    },
  );

  if (handshakeMessage is! SendPort) {
    throw StateError('Invalid handshake response: expected SendPort');
  }

  return (isolate, receivePort, handshakeMessage);
}

/// Kill a platform worker
void killPlatformWorker(PlatformIsolate isolate) {
  isolate.kill(priority: Isolate.immediate);
}
