import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/generated/models/bulk_delete_sessions_body.dart';
import 'package:vagina/api/generated/models/get_session_success_body.dart'
    as api_model;
import 'package:vagina/api/generated/models/list_sessions_success_body_items_item.dart'
    as api_model;
import 'package:vagina/api/generated/models/session_thread.dart' as api_model;
import 'package:vagina/api/generated/responses/bulk_delete_sessions_response.dart';
import 'package:vagina/api/generated/responses/delete_session_response.dart';
import 'package:vagina/api/generated/responses/get_session_response.dart';
import 'package:vagina/api/generated/responses/list_sessions_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread_json_codec.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/models/call_session.dart';

final class SavedThreadCannotBeDisplayedException implements Exception {
  final Object cause;

  const SavedThreadCannotBeDisplayedException(this.cause);

  @override
  String toString() => 'Saved thread cannot be displayed: $cause';
}

class ApiCallSessionRepository implements CallSessionRepository {
  final VaginaApiClient _apiClient;

  const ApiCallSessionRepository({required VaginaApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<CallSessionPage> list({String? cursor, int? limit}) async {
    final response = await _apiClient.sessions.listSessions(
      cursor: cursor,
      limit: limit,
    );

    switch (response) {
      case ListSessionsResponseSuccess(:final data):
        return CallSessionPage(
          items: data.items.map(_fromListItem).toList(growable: false),
          nextCursor: data.nextCursor,
        );
      case ListSessionsResponseBadRequest(:final data):
        throw ApiException.badRequest(data.message, operation: 'List sessions');
      case ListSessionsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'List sessions',
        );
      case ListSessionsResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'List sessions',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<CallSession?> getById(String id) async {
    final response = await _apiClient.sessions.getSession(sessionId: id);

    switch (response) {
      case GetSessionResponseSuccess(:final data):
        return _fromDetail(data);
      case GetSessionResponseNotFound():
        return null;
      case GetSessionResponseServerError(:final data):
        throw ApiException.serverError(data.message, operation: 'Get session');
      case GetSessionResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'Get session',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<bool> delete(String id) async {
    final response = await _apiClient.sessions.deleteSession(sessionId: id);

    switch (response) {
      case DeleteSessionResponseNoContent():
        return true;
      case DeleteSessionResponseNotFound():
        return false;
      case DeleteSessionResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Delete session',
        );
      case DeleteSessionResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'Delete session',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  @override
  Future<int> bulkDelete(List<String> ids) async {
    final response = await _apiClient.sessions.bulkDeleteSessions(
      body: BulkDeleteSessionsBody(ids: ids),
    );

    switch (response) {
      case BulkDeleteSessionsResponseSuccess(:final data):
        return data.deletedCount;
      case BulkDeleteSessionsResponseBadRequest(:final data):
        throw ApiException.badRequest(
          data.message,
          operation: 'Bulk delete sessions',
        );
      case BulkDeleteSessionsResponseServerError(:final data):
        throw ApiException.serverError(
          data.message,
          operation: 'Bulk delete sessions',
        );
      case BulkDeleteSessionsResponseUnknown(:final statusCode, :final body):
        throw _unknownResponseError(
          operation: 'Bulk delete sessions',
          statusCode: statusCode,
          body: body,
        );
    }
  }

  CallSession _fromListItem(api_model.ListSessionsSuccessBodyItemsItem item) {
    return CallSession(
      id: item.id,
      startedAt: item.startedAt,
      endedAt: item.endedAt,
    );
  }

  CallSession _fromDetail(api_model.GetSessionSuccessBody item) {
    return CallSession(
      id: item.id,
      startedAt: item.startedAt,
      endedAt: item.endedAt,
      speedDialId: item.speedDialId,
      voiceAgentId: item.voiceAgentId,
      thread: _decodeThread(item.thread),
    );
  }

  RealtimeThread _decodeThread(api_model.SessionThread thread) {
    try {
      return RealtimeThreadJsonCodec.fromJson({
        'id': thread.id,
        'conversationId': thread.conversationId,
        'items': thread.items,
      });
    } on RealtimeThreadJsonDecodeException catch (error) {
      throw SavedThreadCannotBeDisplayedException(error);
    } on TypeError catch (error) {
      throw SavedThreadCannotBeDisplayedException(error);
    }
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
