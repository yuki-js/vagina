import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_vhrp_connector_io.dart'
    if (dart.library.html) 'websocket_vhrp_connector_web.dart';

/// Returns a connected [WebSocketChannel] for a VHRP/1 endpoint.
///
/// Selects [IOWebSocketChannel] on native/desktop and [HtmlWebSocketChannel]
/// on the web platform via conditional import.
///
/// The returned channel has already passed [WebSocketChannel.ready] — i.e.
/// the WS handshake succeeded.  Throws on failure.
Future<WebSocketChannel> connectVhrpWebSocketChannel(
  Uri uri, {
  List<String> protocols = const [],
}) {
  return connectVhrpWebSocketChannelImpl(uri, protocols: protocols);
}
