import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/generated/core/json_optional.dart';
import 'package:vagina/api/generated/models/speed_dial.dart' as api_model;
import 'package:vagina/api/generated/models/speed_dial_reasoning_effort.dart'
    as api_reasoning;
import 'package:vagina/api/generated/responses/delete_speed_dial_response.dart';
import 'package:vagina/api/generated/responses/get_speed_dial_response.dart';
import 'package:vagina/api/generated/responses/list_speed_dials_response.dart';
import 'package:vagina/api/generated/responses/save_speed_dial_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:logging/logging.dart';

class ApiSpeedDialRepository implements SpeedDialRepository {
  static final Logger _logger = Logger('ApiSpeedDialRepository');

  final VaginaApiClient _apiClient;

  ApiSpeedDialRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<void> save(SpeedDial speedDial) async {
    _logger.fine('Saving speed dial: ${speedDial.id}');
    final response = await _apiClient.speedDials.saveSpeedDial(
      speedDialId: speedDial.id,
      body: _toApiModel(speedDial),
    );

    switch (response) {
      case SaveSpeedDialResponseSuccess():
        return;
      case SaveSpeedDialResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Save speed dial',
        );
      case SaveSpeedDialResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Save speed dial',
        );
      case SaveSpeedDialResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'Save speed dial',
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
        throw _unknownResponseError(
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
        throw _unknownResponseError(
          operation: 'Get speed dial',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> update(SpeedDial speedDial) async {
    await save(speedDial);
    return true;
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
        throw _unknownResponseError(
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
      description: _optionalString(speedDial.description),
      iconEmoji: _optionalString(speedDial.iconEmoji),
      voice: speedDial.voice,
      voiceAgentId: speedDial.voiceAgentId,
      enabledTools: Map<String, bool>.from(speedDial.enabledTools),
      reasoningEffort: _reasoningEffortFromApi(speedDial.reasoningEffort),
      toolChoiceRequired: speedDial.toolChoiceRequired,
      createdAt: _optionalDateTime(speedDial.createdAt),
    );
  }

  api_model.SpeedDial _toApiModel(SpeedDial speedDial) {
    return api_model.SpeedDial(
      id: speedDial.id,
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
      enabledTools: Map<String, bool>.from(speedDial.enabledTools),
      reasoningEffort: _reasoningEffortToApi(speedDial.reasoningEffort),
      toolChoiceRequired: speedDial.toolChoiceRequired,
      createdAt: speedDial.createdAt == null
          ? const JsonOptional<DateTime>.absent()
          : JsonOptional<DateTime>.value(speedDial.createdAt!.toUtc()),
    );
  }

  String? _optionalString(JsonOptional<String> value) {
    return switch (value) {
      JsonOptionalValue<String>(:final value) => value,
      JsonOptionalAbsent<String>() => null,
    };
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

  api_reasoning.SpeedDialReasoningEffort _reasoningEffortToApi(
    SpeedDialReasoningEffort value,
  ) {
    for (final effort in api_reasoning.SpeedDialReasoningEffort.values) {
      if (effort.name == value.name) {
        return effort;
      }
    }
    return api_reasoning.SpeedDialReasoningEffort.off;
  }

  DateTime? _optionalDateTime(JsonOptional<DateTime> value) {
    return switch (value) {
      JsonOptionalValue<DateTime>(:final value) => value,
      JsonOptionalAbsent<DateTime>() => null,
    };
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
