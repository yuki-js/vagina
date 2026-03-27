import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';

/// Transport abstraction for the OpenAI Realtime binding.
///
/// This layer only owns connection lifecycle and JSON frame I/O. It does not
/// perform event accumulation, business interpretation, or provider-agnostic
/// mapping.
abstract interface class OaiRealtimeTransport {
  Stream<Map<String, dynamic>> get inboundMessages;

  Stream<OaiRealtimeConnectionState> get connectionStates;

  bool get isConnected;

  Future<void> connect(OaiRealtimeConnectConfig config);

  Future<void> sendJson(Map<String, dynamic> payload);

  Future<void> disconnect();

  Future<void> dispose();
}
