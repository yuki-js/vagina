/// Abstract API for call control operations
///
/// This API allows tools running in isolates to control call behavior.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class CallApi {
  /// End the current call
  ///
  /// Arguments:
  /// - endContext: Optional context string about why the call is ending
  ///
  /// Returns true if successful, false otherwise
  Future<bool> endCall({String? endContext});
}

/// Client implementation of CallApi that uses hostCall for isolate communication
class CallApiClient implements CallApi {
  final Future<dynamic> Function(String method, Map<String, dynamic> args) hostCall;

  CallApiClient({required this.hostCall});

  @override
  Future<bool> endCall({String? endContext}) async {
    final args = <String, dynamic>{};
    if (endContext != null) {
      args['endContext'] = endContext;
    }

    await hostCall('end', args);
    return true;
  }
}
