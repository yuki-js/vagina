import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../services/realtime_api_client.dart';

/// Provider for the WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the Realtime API client
final realtimeApiClientProvider = Provider<RealtimeApiClient>((ref) {
  final client = RealtimeApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});

/// Provider for connection state
final isConnectedProvider = StateProvider<bool>((ref) => false);

/// Provider for call duration in seconds
final callDurationProvider = StateProvider<int>((ref) => 0);
