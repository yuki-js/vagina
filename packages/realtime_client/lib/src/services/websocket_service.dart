import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service for WebSocket communication
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Connect to a WebSocket server
  Future<void> connect(String url, {Map<String, String>? headers}) async {
    if (_isConnected) {
      await disconnect();
    }

    _channel = WebSocketChannel.connect(
      Uri.parse(url),
      protocols: headers != null ? null : null,
    );

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _messageController.add(message);
        } catch (e) {
          // Handle non-JSON messages
        }
      },
      onError: (error) {
        _isConnected = false;
      },
      onDone: () {
        _isConnected = false;
      },
    );

    _isConnected = true;
  }

  /// Send a message through the WebSocket
  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Send raw data through the WebSocket
  void sendRaw(dynamic data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(data);
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
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
