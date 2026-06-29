import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/generated/models/list_text_agent_models_success_body_item.dart'
    as api_model;
import 'package:vagina/api/generated/responses/list_text_agent_models_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

class ApiTextAgentModelRepository implements TextAgentModelRepository {
  final VaginaApiClient _apiClient;

  const ApiTextAgentModelRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<TextAgentModelPreset>> listTextAgentModels() async {
    final response = await _apiClient.textAgentModels.listTextAgentModels();

    switch (response) {
      case ListTextAgentModelsResponseSuccess(:final data):
        return data.map(_fromApiModel).toList(growable: false);
      case ListTextAgentModelsResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'List text agent models',
        );
      case ListTextAgentModelsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'List text agent models',
        );
      case ListTextAgentModelsResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'List text agent models',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  TextAgentModelPreset _fromApiModel(
    api_model.ListTextAgentModelsSuccessBodyItem item,
  ) {
    return TextAgentModelPreset(
      id: item.id,
      displayName: item.displayName,
      isDefault: item.isDefault,
    );
  }

  ApiException _unknownResponseError({
    required String operation,
    required int statusCode,
    required dynamic body,
  }) {
    return ApiException.unknown(
      _extractMessage(
        body,
        fallback: '$operation failed (status: $statusCode).',
      ),
      statusCode: statusCode,
      operation: operation,
    );
  }

  String _extractMessage(dynamic body, {required String fallback}) {
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}
