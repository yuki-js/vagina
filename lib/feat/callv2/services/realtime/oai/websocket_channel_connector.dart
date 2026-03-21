import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_channel_connector_io.dart'
    if (dart.library.html) 'websocket_channel_connector_web.dart';

Future<WebSocketChannel> connectOaiWebSocketChannel(
  Uri uri, {
  Map<String, dynamic>? headers,
}) {
  return connectOaiWebSocketChannelImpl(uri, headers: headers);
}
