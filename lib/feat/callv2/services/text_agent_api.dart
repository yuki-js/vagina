import 'package:vagina/feat/callv2/services/text_agent_service.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Session-scoped text-agent adapter placeholder for CallV2.
///
/// This class intentionally keeps only the wiring skeleton between
/// [`CallService`](lib/feat/callv2/services/call_service.dart) and
/// [`TextAgentService`](lib/feat/callv2/services/text_agent_service.dart).
/// Query execution and agent exposure are intentionally not implemented yet.
final class CallTextAgentApi implements TextAgentApi {
  final TextAgentService _textAgentService;

  CallTextAgentApi({
    required TextAgentService textAgentService,
  }) : _textAgentService = textAgentService;

  TextAgentService get textAgentService => _textAgentService;

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<String> sendQuery(String agentId, String prompt) {
    throw UnsupportedError(
      'CallV2 text-agent query execution is not implemented.',
    );
  }
}
