import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectOaiWebSocketChannelImpl(
  Uri uri, {
  Map<String, dynamic>? headers,
  List<String>? protocols,
}) async {
  if (headers != null && headers.isNotEmpty) {
    throw UnsupportedError(
      'Custom WebSocket headers are not supported on web. '
      'Use WebSocket subprotocol authentication, query-string auth, or '
      'WebRTC in the browser.',
    );
  }

  final primaryChannel = HtmlWebSocketChannel.connect(
    uri.toString(),
    protocols: protocols,
  );

  try {
    await primaryChannel.ready;
    return primaryChannel;
  } catch (_) {
    final fallbackUri = _buildQueryStringFallbackUri(uri, protocols);
    if (fallbackUri == null) {
      rethrow;
    }

    final fallbackChannel = HtmlWebSocketChannel.connect(fallbackUri.toString());
    await fallbackChannel.ready;
    return fallbackChannel;
  }
}

Uri? _buildQueryStringFallbackUri(Uri uri, List<String>? protocols) {
  final token = _extractProtocolApiKey(protocols);
  if (token == null || token.isEmpty) {
    return null;
  }

  if (uri.queryParameters.containsKey('api-key')) {
    return uri;
  }

  return uri.replace(
    queryParameters: <String, String>{
      ...uri.queryParameters,
      'api-key': token,
    },
  );
}

String? _extractProtocolApiKey(List<String>? protocols) {
  if (protocols == null) {
    return null;
  }

  for (final protocol in protocols) {
    const prefix = 'openai-insecure-api-key.';
    if (protocol.startsWith(prefix) && protocol.length > prefix.length) {
      return protocol.substring(prefix.length);
    }
  }

  return null;
}
