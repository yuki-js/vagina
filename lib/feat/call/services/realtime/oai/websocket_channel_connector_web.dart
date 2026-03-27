import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectOaiWebSocketChannelImpl(
  Uri uri, {
  Map<String, dynamic>? headers,
}) async {
  if (headers != null && headers.isNotEmpty) {
    throw UnsupportedError(
      'Custom WebSocket headers are not supported on web. '
      'Use a relay or a provider flow that authenticates without custom '
      'headers in the browser.',
    );
  }

  return HtmlWebSocketChannel.connect(uri.toString());
}
