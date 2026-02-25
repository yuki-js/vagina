/// Web platform abstraction for sandbox spawning
///
/// Provides platform-specific types and spawn function for Web (pseudo-isolate)
library sandbox_platform;

import 'dart:async';
import 'web_pseudo_isolate.dart';

/// Platform-specific ReceivePort type (WebReceivePort on Web)
typedef PlatformReceivePort = WebReceivePort;

/// Platform-specific SendPort type (WebSendPort on Web)
typedef PlatformSendPort = WebSendPort;

/// Platform-specific Isolate handle type (WebPseudoIsolate on Web)
typedef PlatformIsolate = WebPseudoIsolate;

/// Spawn a worker on Web platform
///
/// Creates a pseudo-worker in the same thread using WebReceivePort/WebSendPort.
///
/// Returns: (pseudo-isolate handle, host receive port, worker send port from handshake)
Future<(PlatformIsolate, PlatformReceivePort, PlatformSendPort)>
    spawnPlatformWorker(
  void Function(WebSendPort) entryPoint,
  Duration timeout,
) async {
  // Create receive port for host-side listening
  final receivePort = WebReceivePort();

  // Spawn the pseudo-worker (runs synchronously in same thread)
  final (pseudoIsolate, workerReceivePort) = await spawnWorker(
    entryPoint,
    receivePort.sendPort,
  );

  // Wait for handshake response with worker's SendPort
  final completer = Completer<Object?>();
  late StreamSubscription<Object?> subscription;

  subscription = receivePort.listen((msg) {
    if (!completer.isCompleted) {
      completer.complete(msg);
      subscription.cancel();
    }
  });

  final handshakeMessage = await completer.future.timeout(
    timeout,
    onTimeout: () {
      subscription.cancel();
      throw TimeoutException(
        'Handshake timeout: worker did not respond within $timeout',
      );
    },
  );

  if (handshakeMessage is! WebSendPort) {
    throw StateError('Invalid handshake response: expected WebSendPort');
  }

  return (pseudoIsolate, receivePort, handshakeMessage);
}

/// Kill a platform worker
void killPlatformWorker(PlatformIsolate pseudoIsolate) {
  pseudoIsolate.kill();
}
