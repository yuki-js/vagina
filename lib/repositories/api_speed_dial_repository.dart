import 'package:logging/logging.dart';
import 'package:vagina/api/api_exception.dart';
import 'package:vagina/repositories/api_repository_error.dart';
import 'package:vagina/api/generated/core/json_optional.dart';
import 'package:vagina/api/generated/models/speed_dial.dart' as api_model;
import 'package:vagina/api/generated/models/speed_dial_create_request.dart';
import 'package:vagina/api/generated/models/speed_dial_create_request_reasoning_effort.dart'
    as api_create_reasoning;
import 'package:vagina/api/generated/models/speed_dial_reasoning_effort.dart'
    as api_reasoning;
import 'package:vagina/api/generated/models/speed_dial_update_request.dart';
import 'package:vagina/api/generated/models/speed_dial_update_request_reasoning_effort.dart'
    as api_update_reasoning;
import 'package:vagina/api/generated/responses/create_speed_dial_response.dart';
import 'package:vagina/api/generated/responses/delete_speed_dial_response.dart';
import 'package:vagina/api/generated/responses/get_speed_dial_response.dart';
import 'package:vagina/api/generated/responses/list_speed_dials_response.dart';
import 'package:vagina/api/generated/responses/update_speed_dial_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/models/speed_dial.dart';

class ApiSpeedDialRepository implements SpeedDialRepository {
  static final Logger _logger = Logger('ApiSpeedDialRepository');

  final VaginaApiClient _apiClient;

  ApiSpeedDialRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<SpeedDial> create({
    required String name,
    required String systemPrompt,
    String? description,
    String? iconEmoji,
    String voice = 'alloy',
    String voiceAgentId = SpeedDial.defaultVoiceAgentId,
    Map<String, bool> enabledTools = const {},
    SpeedDialReasoningEffort reasoningEffort = SpeedDialReasoningEffort.off,
    bool toolChoiceRequired = false,
  }) async {
    _logger.fine('Creating speed dial');
    final response = await _apiClient.speedDials.createSpeedDial(
      body: SpeedDialCreateRequest(
        name: name,
        systemPrompt: systemPrompt,
        description: description,
        iconEmoji: iconEmoji,
        voice: voice,
        voiceAgentId: voiceAgentId,
        enabledTools: Map<String, dynamic>.from(enabledTools),
        reasoningEffort: _reasoningEffortToCreateApi(reasoningEffort),
        toolChoiceRequired: toolChoiceRequired,
      ),
    );

    switch (response) {
      case CreateSpeedDialResponseCreated(:final data):
        return _fromApiModel(data);
      case CreateSpeedDialResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Create speed dial',
        );
      case CreateSpeedDialResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Create speed dial',
        );
      case CreateSpeedDialResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Create speed dial',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<List<SpeedDial>> getAll() async {
    _logger.fine('Loading all speed dials');
    final response = await _apiClient.speedDials.listSpeedDials();

    switch (response) {
      case ListSpeedDialsResponseSuccess(:final data):
        return data.map(_fromApiModel).toList(growable: false);
      case ListSpeedDialsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'List speed dials',
        );
      case ListSpeedDialsResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'List speed dials',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<SpeedDial?> getById(String id) async {
    _logger.fine('Loading speed dial by id: $id');
    final response = await _apiClient.speedDials.getSpeedDial(speedDialId: id);

    switch (response) {
      case GetSpeedDialResponseSuccess(:final data):
        return _fromApiModel(data);
      case GetSpeedDialResponseNotFound():
        return null;
      case GetSpeedDialResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Get speed dial',
        );
      case GetSpeedDialResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Get speed dial',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> update(SpeedDial speedDial) async {
    _logger.fine('Updating speed dial: ${speedDial.id}');
    final response = await _apiClient.speedDials.updateSpeedDial(
      speedDialId: speedDial.id,
      body: SpeedDialUpdateRequest(
        name: speedDial.name,
        systemPrompt: speedDial.systemPrompt,
        description: speedDial.description == null
            ? const JsonOptional<String>.absent()
            : JsonOptional<String>.value(speedDial.description),
        iconEmoji: speedDial.iconEmoji == null
            ? const JsonOptional<String>.absent()
            : JsonOptional<String>.value(speedDial.iconEmoji),
        voice: speedDial.voice,
        voiceAgentId: speedDial.voiceAgentId,
        enabledTools: Map<String, dynamic>.from(speedDial.enabledTools),
        reasoningEffort: _reasoningEffortToUpdateApi(speedDial.reasoningEffort),
        toolChoiceRequired: speedDial.toolChoiceRequired,
      ),
    );

    switch (response) {
      case UpdateSpeedDialResponseSuccess():
        return true;
      case UpdateSpeedDialResponseNotFound():
      case UpdateSpeedDialResponseConflict():
        return false;
      case UpdateSpeedDialResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Update speed dial',
        );
      case UpdateSpeedDialResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Update speed dial',
        );
      case UpdateSpeedDialResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Update speed dial',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> delete(String id) async {
    _logger.fine('Deleting speed dial: $id');
    final response = await _apiClient.speedDials.deleteSpeedDial(
      speedDialId: id,
    );

    switch (response) {
      case DeleteSpeedDialResponseNoContent():
        return true;
      case DeleteSpeedDialResponseNotFound():
      case DeleteSpeedDialResponseConflict():
        return false;
      case DeleteSpeedDialResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Delete speed dial',
        );
      case DeleteSpeedDialResponseUnknown(:final statusCode, :final body):
        throw unknownApiResponseError(
          operation: 'Delete speed dial',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  SpeedDial _fromApiModel(api_model.SpeedDial speedDial) {
    return SpeedDial(
      id: speedDial.id,
      name: speedDial.name,
      systemPrompt: speedDial.systemPrompt,
      description: speedDial.description,
      iconEmoji: speedDial.iconEmoji,
      voice: speedDial.voice,
      voiceAgentId: speedDial.voiceAgentId,
      enabledTools: _boolMapFromDynamic(speedDial.enabledTools),
      reasoningEffort: _reasoningEffortFromApi(speedDial.reasoningEffort),
      toolChoiceRequired: speedDial.toolChoiceRequired,
      createdAt: speedDial.createdAt,
    );
  }

  Map<String, bool> _boolMapFromDynamic(Map<String, dynamic> value) {
    return value.map((key, value) => MapEntry(key, value == true));
  }

  SpeedDialReasoningEffort _reasoningEffortFromApi(
    api_reasoning.SpeedDialReasoningEffort value,
  ) {
    for (final effort in SpeedDialReasoningEffort.values) {
      if (effort.name == value.name) {
        return effort;
      }
    }
    return SpeedDialReasoningEffort.off;
  }

  api_create_reasoning.SpeedDialCreateRequestReasoningEffort
  _reasoningEffortToCreateApi(SpeedDialReasoningEffort value) {
    for (final effort
        in api_create_reasoning.SpeedDialCreateRequestReasoningEffort.values) {
      if (effort.name == value.name) {
        return effort;
      }
    }
    return api_create_reasoning.SpeedDialCreateRequestReasoningEffort.off;
  }

  api_update_reasoning.SpeedDialUpdateRequestReasoningEffort
  _reasoningEffortToUpdateApi(SpeedDialReasoningEffort value) {
    for (final effort
        in api_update_reasoning.SpeedDialUpdateRequestReasoningEffort.values) {
      if (effort.name == value.name) {
        return effort;
      }
    }
    return api_update_reasoning.SpeedDialUpdateRequestReasoningEffort.off;
  }
}
