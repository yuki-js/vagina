import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_transport.dart';
import 'websocket_channel_connector.dart';

typedef OaiRealtimeSocketConnector = Future<WebSocketChannel> Function(
  Uri uri, {
  Map<String, dynamic>? headers,
  List<String>? protocols,
});

final class WebSocketOaiRealtimeTransport implements OaiRealtimeTransport {
  final OaiRealtimeSocketConnector _connector;
  final Duration _initialReconnectDelay;
  final int _maxInitialReconnectAttempts;

  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<OaiRealtimeConnectionState> _stateController =
      StreamController<OaiRealtimeConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  OaiRealtimeConnectionState _lastState =
      const OaiRealtimeConnectionState.idle();
  bool _disposed = false;

  WebSocketOaiRealtimeTransport({
    OaiRealtimeSocketConnector? connector,
    Duration initialReconnectDelay = const Duration(milliseconds: 400),
    int maxInitialReconnectAttempts = 2,
  })  : _connector = connector ?? connectOaiWebSocketChannel,
        _initialReconnectDelay = initialReconnectDelay,
        _maxInitialReconnectAttempts = maxInitialReconnectAttempts;

  @override
  Stream<Map<String, dynamic>> get inboundMessages => _inboundController.stream;

  @override
  Stream<OaiRealtimeConnectionState> get connectionStates =>
      _stateController.stream;

  @override
  bool get isConnected => _lastState.isConnected;

  @override
  Future<void> connect(OaiRealtimeConnectConfig config) async {
    _ensureNotDisposed();

    if (_channel != null) {
      await disconnect();
    }

    final target = _buildTarget(config);
    Object? lastError;

    for (var attempt = 1; attempt <= _maxInitialReconnectAttempts; attempt++) {
      final isRetry = attempt > 1;
      _emitState(
        isRetry
            ? OaiRealtimeConnectionState.reconnecting(attempt: attempt)
            : OaiRealtimeConnectionState.connecting(attempt: attempt),
      );

      try {
        _channel = await _connector(
          target.uri,
          headers: target.headers,
          protocols: target.protocols,
        );
        _subscription = _channel!.stream.listen(
          _handleFrame,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
          cancelOnError: false,
        );
        _emitState(OaiRealtimeConnectionState.connected(attempt: attempt));
        return;
      } catch (error) {
        lastError = error;
        await _safeTearDownChannel();
        if (attempt < _maxInitialReconnectAttempts) {
          await Future<void>.delayed(_initialReconnectDelay);
        }
      }
    }

    _emitState(
      OaiRealtimeConnectionState.failed(
        attempt: _maxInitialReconnectAttempts,
        message:
            'Failed to connect after $_maxInitialReconnectAttempts attempts.',
        error: lastError,
      ),
    );
    throw lastError ?? StateError('Failed to connect realtime transport.');
  }

  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {
    _ensureNotDisposed();
    final channel = _channel;
    if (channel == null || !isConnected) {
      throw StateError('Cannot send realtime payload while disconnected.');
    }

    channel.sink.add(jsonEncode(payload));
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) {
      return;
    }
    if (_channel == null && _subscription == null) {
      _emitState(const OaiRealtimeConnectionState.disconnected());
      return;
    }

    _emitState(const OaiRealtimeConnectionState.disconnecting());
    await _safeTearDownChannel();
    _emitState(const OaiRealtimeConnectionState.disconnected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _safeTearDownChannel();
    await _inboundController.close();
    await _stateController.close();
  }

  void _handleFrame(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is! Map) {
        throw const FormatException(
          'Realtime transport received a non-object JSON payload.',
        );
      }
      _inboundController.add(Map<String, dynamic>.from(decoded));
    } catch (error) {
      _handleStreamError(
        OaiRealtimeConnectionError(
          code: 'invalid_inbound_message',
          message: 'Failed to decode inbound realtime frame.',
          cause: error,
        ),
      );
    }
  }

  void _handleStreamError(Object error, [StackTrace? stackTrace]) {
    _emitState(
      OaiRealtimeConnectionState.failed(
        attempt: _lastState.attempt,
        message: 'Realtime transport stream failed.',
        error: error,
      ),
    );
  }

  void _handleStreamDone() {
    if (_disposed) {
      return;
    }
    _emitState(
      const OaiRealtimeConnectionState.disconnected(
        message: 'Realtime socket closed.',
      ),
    );
  }

  Future<void> _safeTearDownChannel() async {
    try {
      await _subscription?.cancel();
    } finally {
      _subscription = null;
      final channel = _channel;
      _channel = null;
      if (channel != null) {
        await channel.sink.close();
      }
    }
  }

  _OaiRealtimeTransportTarget _buildTarget(OaiRealtimeConnectConfig config) {
    final baseUri = resolveRealtimeEndpoint(
      config.baseUri,
      epFragment: config.epFragment,
    );
    return _OaiRealtimeTransportTarget(
      uri: baseUri,
      headers: _buildHeaders(config),
      protocols: _buildProtocols(config),
    );
  }

  Map<String, dynamic> _buildHeaders(OaiRealtimeConnectConfig config) {
    if (kIsWeb) {
      return const <String, dynamic>{};
    }

    final headers = <String, dynamic>{
      ...config.extraHeaders,
    };

    final token = config.bearerToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  List<String>? _buildProtocols(OaiRealtimeConnectConfig config) {
    if (!kIsWeb) {
      return null;
    }

    final token = config.bearerToken?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }

    final protocols = <String>[
      'realtime',
      'openai-insecure-api-key.$token',
    ];

    final organization = config.extraHeaders['OpenAI-Organization']?.trim();
    if (organization != null && organization.isNotEmpty) {
      protocols.add('openai-organization.$organization');
    }

    final project = config.extraHeaders['OpenAI-Project']?.trim();
    if (project != null && project.isNotEmpty) {
      protocols.add('openai-project.$project');
    }

    return protocols;
  }

  void _emitState(OaiRealtimeConnectionState state) {
    _lastState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Realtime transport is already disposed.');
    }
  }
}

final class _OaiRealtimeTransportTarget {
  final Uri uri;
  final Map<String, dynamic> headers;
  final List<String>? protocols;

  const _OaiRealtimeTransportTarget({
    required this.uri,
    required this.headers,
    required this.protocols,
  });
}
