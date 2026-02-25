/// Shared mutable state across handlers
class RealtimeState {
  String? lastError;
  int audioChunksReceived = 0;
  int audioChunksSent = 0;

  /// Function call arguments accumulator (deltas → complete)
  final pendingFunctionCalls = <String, StringBuffer>{};
  final pendingFunctionNames = <String, String>{};

  void reset() {
    lastError = null;
    audioChunksReceived = 0;
    audioChunksSent = 0;
    pendingFunctionCalls.clear();
    pendingFunctionNames.clear();
  }
}
