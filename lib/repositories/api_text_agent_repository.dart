import 'package:logging/logging.dart';
import 'package:vagina/api/api_exception.dart';
import 'package:vagina/repositories/api_repository_error.dart';
import 'package:vagina/api/generated/core/json_optional.dart';
import 'package:vagina/api/generated/models/text_agent.dart' as api_model;
import 'package:vagina/api/generated/models/text_agent_write_request.dart';
import 'package:vagina/api/generated/responses/create_text_agent_response.dart';
import 'package:vagina/api/generated/responses/delete_text_agent_response.dart';
import 'package:vagina/api/generated/responses/get_text_agent_response.dart';
import 'package:vagina/api/generated/responses/list_text_agents_response.dart';
import 'package:vagina/api/generated/responses/update_text_agent_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/models/text_agent_definition.dart';

class ApiTextAgentRepository implements TextAgentRepository {
  static final Logger _logger = Logger('ApiTextAgentRepository');

  final VaginaApiClient _apiClient;

  ApiTextAgentRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<TextAgentDefinition> create({
    required String name,
    required String prompt,
    String? description,
    String textModelId = TextAgentDefinition.defaultTextModelId,
    Map<String, bool> enabledTools = const {},
  }) async {
    _logger.fine('Creating text agent');
    final response = await _apiClient.textAgents.createTextAgent(
      body: TextAgentWriteRequest(
        name: name,
        prompt: prompt,
        description: description == null
            ? const JsonOptional<String>.absent()
            : JsonOptional<String>.value(description),
        textModelId: textModelId,
        enabledTools: Map<String, dynamic>.from(enabledTools),
      ),
    );

    switch (response) {
      case CreateTextAgentResponseCreated(:final data):
        return _fromApiModel(data);
      case CreateTextAgentResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Create text agent',
        );
      case CreateTextAgentResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'Create text agent',
        );
      case CreateTextAgentResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Create text agent',
        );
      case CreateTextAgentResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Create text agent',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<List<TextAgentDefinition>> getAll() async {
    _logger.fine('Loading all text agents');
    final response = await _apiClient.textAgents.listTextAgents();

    switch (response) {
      case ListTextAgentsResponseSuccess(:final data):
        return data.map(_fromApiModel).toList(growable: false);
      case ListTextAgentsResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'List text agents',
        );
      case ListTextAgentsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'List text agents',
        );
      case ListTextAgentsResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'List text agents',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<TextAgentDefinition?> getById(String id) async {
    _logger.fine('Loading text agent by id: $id');
    final response = await _apiClient.textAgents.getTextAgent(textAgentId: id);

    switch (response) {
      case GetTextAgentResponseSuccess(:final data):
        return _fromApiModel(data);
      case GetTextAgentResponseNotFound():
        return null;
      case GetTextAgentResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'Get text agent',
        );
      case GetTextAgentResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Get text agent',
        );
      case GetTextAgentResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Get text agent',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> update(TextAgentDefinition textAgent) async {
    _logger.fine('Updating text agent: ${textAgent.id}');
    final response = await _apiClient.textAgents.updateTextAgent(
      textAgentId: textAgent.id,
      body: TextAgentWriteRequest(
        name: textAgent.name,
        prompt: textAgent.prompt,
        description: textAgent.description == null
            ? const JsonOptional<String>.absent()
            : JsonOptional<String>.value(textAgent.description),
        textModelId: textAgent.textModelId,
        enabledTools: Map<String, dynamic>.from(textAgent.enabledTools),
      ),
    );

    switch (response) {
      case UpdateTextAgentResponseSuccess():
        return true;
      case UpdateTextAgentResponseNotFound():
        return false;
      case UpdateTextAgentResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Update text agent',
        );
      case UpdateTextAgentResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'Update text agent',
        );
      case UpdateTextAgentResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Update text agent',
        );
      case UpdateTextAgentResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Update text agent',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> delete(String id) async {
    _logger.fine('Deleting text agent: $id');
    final response = await _apiClient.textAgents.deleteTextAgent(
      textAgentId: id,
    );

    switch (response) {
      case DeleteTextAgentResponseNoContent():
        return true;
      case DeleteTextAgentResponseNotFound():
        return false;
      case DeleteTextAgentResponseUnauthorized(:final data):
        throw ApiException.forbidden(
          data.message,
          statusCode: 401,
          operation: 'Delete text agent',
        );
      case DeleteTextAgentResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Delete text agent',
        );
      case DeleteTextAgentResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Delete text agent',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  TextAgentDefinition _fromApiModel(api_model.TextAgent textAgent) {
    return TextAgentDefinition(
      id: textAgent.id,
      name: textAgent.name,
      prompt: textAgent.prompt,
      description: textAgent.description,
      textModelId: textAgent.textModelId,
      enabledTools: _boolMapFromDynamic(textAgent.enabledTools),
      createdAt: textAgent.createdAt,
    );
  }

  Map<String, bool> _boolMapFromDynamic(Map<String, dynamic> value) {
    return value.map((key, value) => MapEntry(key, value == true));
  }
}
