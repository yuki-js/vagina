import 'dart:async';

import 'package:vagina/feat/call/services/realtime/oai/realtime_binding.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connect_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_connection_state.dart';

/// Test Realtime API connectivity.
///
/// This is a lightweight helper for connection validation in settings/OOBE
/// screens. For actual call sessions, use CallService with proper
/// configuration.
Future<void> testRealtimeConnection(
  String realtimeUrl,
  String bearerToken,
) async {
  final baseUri = Uri.parse(realtimeUrl);
  if (baseUri.scheme.isEmpty || baseUri.host.isEmpty) {
    throw Exception('Invalid Realtime base URI');
  }

  final client = OaiRealtimeClient();
  StreamSubscription<OaiRealtimeConnectionState>? sub;

  try {
    final config = OaiRealtimeConnectConfig(
      baseUri: baseUri,
      bearerToken: bearerToken,
    );

    final completer = Completer<void>();
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

    await client.connect(config);

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timeout');
      },
    );

    await sub.cancel();
    sub = null;
    await client.disconnect();
    await client.dispose();
  } catch (error) {
    try {
      await sub?.cancel();
      await client.disconnect();
      await client.dispose();
    } catch (_) {
      // Ignore cleanup errors.
    }
    rethrow;
  }
}
