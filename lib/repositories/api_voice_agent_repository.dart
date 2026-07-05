import 'package:vagina/api/api_exception.dart';
import 'package:vagina/repositories/api_repository_error.dart';
import 'package:vagina/api/generated/models/list_voice_agents_success_body_item.dart'
    as api_model;
import 'package:vagina/api/generated/responses/list_voice_agents_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/models/voice_agent.dart';

class ApiVoiceAgentRepository implements VoiceAgentRepository {
  final VaginaApiClient _apiClient;

  const ApiVoiceAgentRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<VoiceAgent>> listVoiceAgents() async {
    final response = await _apiClient.voiceAgents.listVoiceAgents();

    switch (response) {
      case ListVoiceAgentsResponseSuccess(:final data):
        return data.map(_fromApiModel).toList(growable: false);
      case ListVoiceAgentsResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'List voice agents',
        );
      case ListVoiceAgentsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'List voice agents',
        );
      case ListVoiceAgentsResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'List voice agents',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  VoiceAgent _fromApiModel(api_model.ListVoiceAgentsSuccessBodyItem item) {
    return VoiceAgent(
      id: item.id,
      displayName: item.displayName,
      isDefault: item.isDefault,
    );
  }
}
