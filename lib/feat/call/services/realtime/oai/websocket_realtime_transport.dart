import 'dart:async';
import 'dart:convert';

import 'package:vagina/services/log_service.dart';
import 'package:vagina/utils/url_utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_transport.dart';
import 'websocket_channel_connector.dart';

typedef OaiRealtimeSocketConnector = Future<WebSocketChannel> Function(
  Uri uri, {
  Map<String, dynamic>? headers,
});

final class WebSocketOaiRealtimeTransport implements OaiRealtimeTransport {
  static const _tag = 'OaiRealtimeTransport';

  final OaiRealtimeSocketConnector _connector;
  final LogService _log;
  final Duration _initialReconnectDelay;
  final int _maxInitialReconnectAttempts;

  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<OaiRealtimeConnectionState> _stateController =
      StreamController<OaiRealtimeConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  OaiRealtimeConnectionState _lastState = const OaiRealtimeConnectionState.idle();
  bool _disposed = false;

  WebSocketOaiRealtimeTransport({
    OaiRealtimeSocketConnector? connector,
    Duration initialReconnectDelay = const Duration(milliseconds: 400),
    int maxInitialReconnectAttempts = 2,
  })  : _connector = connector ?? connectOaiWebSocketChannel,
        _log = LogService(),
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
        final safeUrl = UrlUtils.redactSensitiveParams(target.uri.toString());
        _log.info(_tag, 'Connecting to $safeUrl');
        _channel = await _connector(target.uri, headers: target.headers);
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
        _log.error(_tag, 'Connection attempt $attempt failed: $error');
        await _safeTearDownChannel();
        if (attempt < _maxInitialReconnectAttempts) {
          await Future<void>.delayed(_initialReconnectDelay);
        }
      }
    }

    _emitState(OaiRealtimeConnectionState.failed(
      attempt: _maxInitialReconnectAttempts,
      message: 'Failed to connect after $_maxInitialReconnectAttempts attempts.',
      error: lastError,
    ));
    throw lastError ?? StateError('Failed to connect realtime transport.');
  }

  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {
    _ensureNotDisposed();
    final channel = _channel;
    if (channel == null || !isConnected) {
      throw StateError('Cannot send realtime payload while disconnected.');
    }

    final type = payload['type'] as String? ?? 'unknown';
    _log.websocket('SEND', type, payload);
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
      final message = Map<String, dynamic>.from(decoded);
      final type = message['type'] as String? ?? 'unknown';
      _log.websocket('RECV', type, message);
      _inboundController.add(message);
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
    _log.error(_tag, 'Transport stream error: $error');
    _emitState(OaiRealtimeConnectionState.failed(
      attempt: _lastState.attempt,
      message: 'Realtime transport stream failed.',
      error: error,
    ));
  }

  void _handleStreamDone() {
    _log.info(_tag, 'Realtime socket closed');
    if (_disposed) {
      return;
    }
    _emitState(const OaiRealtimeConnectionState.disconnected(
      message: 'Realtime socket closed.',
    ));
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
    return switch (config) {
      OpenAiRealtimeConnectConfig() => _buildOpenAiTarget(config),
      AzureOpenAiRealtimeConnectConfig() => _buildAzureTarget(config),
    };
  }

  _OaiRealtimeTransportTarget _buildOpenAiTarget(
    OpenAiRealtimeConnectConfig config,
  ) {
    final baseUri = config.baseUri ?? Uri.parse('https://api.openai.com/v1/realtime');
    final wsUri = _normalizeWebSocketUri(baseUri).replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'model': config.model,
      },
    );

    final headers = <String, dynamic>{
      'Authorization': 'Bearer ${config.apiKey}',
      'OpenAI-Beta': 'realtime=v1',
      if (config.organization != null)
        'OpenAI-Organization': config.organization,
      if (config.project != null) 'OpenAI-Project': config.project,
    };

    return _OaiRealtimeTransportTarget(uri: wsUri, headers: headers);
  }

  _OaiRealtimeTransportTarget _buildAzureTarget(
    AzureOpenAiRealtimeConnectConfig config,
  ) {
    final wsUri = _normalizeWebSocketUri(config.endpoint).replace(
      path: _joinUriPath(config.endpoint.path, '/openai/realtime'),
      queryParameters: {
        ...config.endpoint.queryParameters,
        'api-version': config.apiVersion,
        'deployment': config.deployment,
        'api-key': config.apiKey,
      },
    );

    return _OaiRealtimeTransportTarget(uri: wsUri, headers: const {});
  }

  Uri _normalizeWebSocketUri(Uri uri) {
    if (uri.scheme == 'ws' || uri.scheme == 'wss') {
      return uri;
    }
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'wss');
    }
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'ws');
    }
    return uri;
  }

  String _joinUriPath(String basePath, String suffix) {
    final normalizedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final normalizedSuffix = suffix.startsWith('/') ? suffix : '/$suffix';
    return '$normalizedBase$normalizedSuffix';
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

  const _OaiRealtimeTransportTarget({
    required this.uri,
    required this.headers,
  });
}
