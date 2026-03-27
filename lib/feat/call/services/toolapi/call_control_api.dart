import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';

/// Session-scoped [CallApi] implementation for tool execution.
///
/// Routes call control operations back to the owning [CallService].
final class CallControlApi implements CallApi {
  final CallService _callService;

  CallControlApi({required CallService callService})
      : _callService = callService;

  @override
  Future<bool> endCall({String? endContext}) async {
    // Schedule endCall after current tool execution completes
    Future(() => _callService.endCall(endContext: endContext));
    return true;
  }
}
