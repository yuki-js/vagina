import 'dart:async';
import 'package:vagina/feat/call/services/realtime/oai/realtime_binding.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connect_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connection_state.dart';
import 'package:vagina/utils/url_utils.dart';

/// Test Azure OpenAI Realtime API connectivity.
///
/// This is a lightweight helper for connection validation in settings/OOBE screens.
/// For actual call sessions, use CallService with proper configuration.
Future<void> testRealtimeConnection(
  String realtimeUrl,
  String apiKey,
) async {
  final parsed = UrlUtils.parseAzureRealtimeUrl(realtimeUrl);
  if (parsed == null) {
    throw Exception('Invalid Realtime URL format');
  }

  final client = OaiRealtimeClient();
  
  try {
    // Parse URL components
    final uri = Uri.parse(realtimeUrl);
    final endpoint = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
    );
    
    final deployment = (parsed['deployment'] ?? 'gpt-4o-realtime') as String;
    final apiVersion = (parsed['apiVersion'] ?? '2024-10-01-preview') as String;

    // Create connection config
    final config = AzureOpenAiRealtimeConnectConfig(
      apiKey: apiKey,
      endpoint: endpoint,
      deployment: deployment,
      apiVersion: apiVersion,
    );

    // Connect and wait for connection state
    final completer = Completer<void>();
    StreamSubscription<OaiRealtimeConnectionState>? sub;
    
    sub = client.connectionStates.listen((state) {
      if (state.phase == OaiRealtimeConnectionPhase.connected) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (state.phase == OaiRealtimeConnectionPhase.failed) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(state.message ?? 'Connection failed'),
          );
        }
      }
    });

    // Initiate connection
    await client.connect(config);

    // Wait for connection or timeout
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timeout');
      },
    );

    // Clean up
    await sub.cancel();
    await client.disconnect();
    await client.dispose();
  } catch (e) {
    // Ensure cleanup
    try {
      await client.disconnect();
      await client.dispose();
    } catch (_) {
      // Ignore cleanup errors
    }
    rethrow;
  }
}
