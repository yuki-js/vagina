/// Web platform pseudo-implementation of Dart Isolate ports
///
/// Provides SendPort/ReceivePort-like APIs that work in single-threaded
/// JavaScript environments. Messages are delivered via microtasks to
/// emulate asynchronous behavior while maintaining protocol compatibility.
library web_pseudo_isolate;

import 'dart:async';
import 'dart:collection';

/// Pseudo SendPort for Web environments
///
/// Provides a send() method that enqueues messages to a paired ReceivePort.
/// Messages are delivered asynchronously via microtasks.
class WebSendPort {
  final WebReceivePort _targetPort;
  
  WebSendPort._(this._targetPort);
  
  /// Send a message to the paired ReceivePort
  ///
  /// The message is enqueued and will be delivered asynchronously via
  /// microtask. If the target port is closed, the message is silently dropped.
  void send(Object? message) {
    _targetPort._enqueue(message);
  }
  
  @override
  String toString() => 'WebSendPort($_targetPort)';
}

/// Pseudo ReceivePort for Web environments
///
/// Provides listen/close APIs compatible with dart:isolate ReceivePort.
/// Messages are delivered via a StreamController.
class WebReceivePort {
  final Queue<Object?> _messageQueue = Queue<Object?>();
  final StreamController<Object?> _controller = StreamController<Object?>.broadcast();
  bool _isClosed = false;
  bool _isFlushing = false;
  late final WebSendPort sendPort;
  
  WebReceivePort() {
    sendPort = WebSendPort._(this);
  }
  
  /// Listen to incoming messages
  ///
  /// Only one listener is allowed (mimics ReceivePort behavior).
  /// - onData: Called for each received message
  /// - onError: Called on stream errors (optional)
  /// - onDone: Called when port is closed
  StreamSubscription<Object?> listen(
    void Function(Object? message) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
  
  /// Close the port
  ///
  /// After closing:
  /// - No more messages will be delivered
  /// - Pending messages in queue are discarded
  /// - onDone callbacks are invoked
  void close() {
    if (_isClosed) return;
    
    _isClosed = true;
    _messageQueue.clear();
    _controller.close();
  }
  
  /// Internal: Enqueue a message for delivery
  void _enqueue(Object? message) {
    if (_isClosed) {
      // Silently drop messages sent to closed port (matches ReceivePort behavior)
      return;
    }
    
    _messageQueue.add(message);
    _scheduleFlush();
  }
  
  /// Internal: Schedule message delivery via microtask
  void _scheduleFlush() {
    if (_isFlushing || _isClosed) return;
    
    _isFlushing = true;
    scheduleMicrotask(() {
      _flush();
    });
  }
  
  /// Internal: Flush queued messages to stream
  void _flush() {
    _isFlushing = false;
    
    if (_isClosed) return;
    
    while (_messageQueue.isNotEmpty && !_isClosed) {
      final message = _messageQueue.removeFirst();
      _controller.add(message);
    }
  }
  
  @override
  String toString() => 'WebReceivePort(closed: $_isClosed)';
}

/// Create a pair of connected ports for bidirectional communication
///
/// Returns a tuple of (hostReceivePort, workerReceivePort) where:
/// - Messages sent to hostReceivePort.sendPort are received by hostReceivePort
/// - Messages sent to workerReceivePort.sendPort are received by workerReceivePort
///
/// This is used to emulate the host-worker communication pattern:
/// - Host creates hostReceivePort and sends hostReceivePort.sendPort to worker
/// - Worker creates workerReceivePort and sends workerReceivePort.sendPort to host
///
/// Usage:
/// ```dart
/// final (hostPort, workerPort) = createPortPair();
/// // Host listens on hostPort, worker listens on workerPort
/// // Host sends to workerPort.sendPort, worker sends to hostPort.sendPort
/// ```
(WebReceivePort, WebReceivePort) createPortPair() {
  final hostPort = WebReceivePort();
  final workerPort = WebReceivePort();
  return (hostPort, workerPort);
}

/// Spawn a "worker" in the same thread
///
/// This emulates Isolate.spawn behavior for Web environments.
/// The worker function runs synchronously in the same thread.
///
/// Parameters:
/// - entryPoint: Function to run as "worker"
/// - message: Initial message (typically a SendPort)
///
/// Returns: A pair of (pseudoIsolate, workerReceivePort) where:
/// - pseudoIsolate: Can be "killed" via kill() method
/// - workerReceivePort: The receive port the worker will use
///
/// The worker should:
/// 1. Extract the host's SendPort from the initial message
/// 2. Create its own ReceivePort and send its SendPort back
/// 3. Listen for messages on its ReceivePort
Future<(WebPseudoIsolate, WebReceivePort)> spawnWorker(
  void Function(WebSendPort message) entryPoint,
  WebSendPort message,
) async {
  final workerReceivePort = WebReceivePort();
  final pseudoIsolate = WebPseudoIsolate._(workerReceivePort);
  
  // Run worker entrypoint synchronously
  // (in real Web Worker version, this would be postMessage to worker)
  scheduleMicrotask(() {
    try {
      entryPoint(message);
    } catch (e, stack) {
      print('WebPseudoIsolate: Worker error: $e');
      print(stack);
      pseudoIsolate.kill();
    }
  });
  
  return (pseudoIsolate, workerReceivePort);
}

/// Pseudo Isolate handle for Web
///
/// Represents a "worker" that can be killed. In single-threaded Web,
/// this just closes the worker's receive port.
class WebPseudoIsolate {
  final WebReceivePort _workerPort;
  bool _isKilled = false;
  
  WebPseudoIsolate._(this._workerPort);
  
  /// Kill the "worker"
  ///
  /// In single-threaded mode, this closes the worker's receive port,
  /// which triggers onDone and prevents further message processing.
  void kill({int priority = 0}) {
    if (_isKilled) return;
    _isKilled = true;
    _workerPort.close();
  }
  
  bool get isKilled => _isKilled;
  
  @override
  String toString() => 'WebPseudoIsolate(killed: $_isKilled)';
}
