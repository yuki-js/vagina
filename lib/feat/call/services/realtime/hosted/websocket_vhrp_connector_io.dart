import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectVhrpWebSocketChannelImpl(
  Uri uri, {
  List<String> protocols = const [],
}) async {
  final channel = IOWebSocketChannel.connect(uri, protocols: protocols);
  await channel.ready;
  return channel;
}
