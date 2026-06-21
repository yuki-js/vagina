import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectVhrpWebSocketChannelImpl(
  Uri uri, {
  List<String> protocols = const [],
}) async {
  final channel = HtmlWebSocketChannel.connect(
    uri.toString(),
    protocols: protocols,
  );
  await channel.ready;
  return channel;
}
