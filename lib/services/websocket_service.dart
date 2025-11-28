import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'log_service.dart';
import '../utils/url_utils.dart';

/// Service for WebSocket communication
class WebSocketService {
  static const _tag = 'WebSocket';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Connect to a WebSocket server
  /// The URL should include any authentication parameters (e.g., api-key query parameter)
  Future<void> connect(String url) async {
    if (_isConnected) {
      logService.info(_tag, 'Already connected, disconnecting first');
      await disconnect();
    }

    // Log URL without API key for security
    final safeUrl = UrlUtils.redactSensitiveParams(url);
    logService.info(_tag, 'Connecting to: $safeUrl');

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          final type = message['type'] as String?;
          logService.websocket('RECV', type ?? 'unknown', message);
          _messageController.add(message);
        } catch (e) {
          logService.error(_tag, 'Failed to parse message: $e');
        }
      },
      onError: (error) {
        logService.error(_tag, 'Connection error: $error');
        _isConnected = false;
      },
      onDone: () {
        logService.info(_tag, 'Connection closed');
        _isConnected = false;
      },
    );

    _isConnected = true;
    logService.info(_tag, 'Connected successfully');
  }

  /// Send a message through the WebSocket
  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      final type = message['type'] as String?;
      logService.websocket('SEND', type ?? 'unknown', message);
      _channel!.sink.add(jsonEncode(message));
    } else {
      logService.warn(_tag, 'Cannot send message: not connected');
    }
  }

  /// Send raw data through the WebSocket
  void sendRaw(dynamic data) {
    if (_isConnected && _channel != null) {
      logService.debug(_tag, 'Sending raw data');
      _channel!.sink.add(data);
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    logService.info(_tag, 'Disconnecting');
    _isConnected = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  /// Dispose the service
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}
