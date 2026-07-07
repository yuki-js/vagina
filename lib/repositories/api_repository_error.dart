import 'package:vagina/api/api_exception.dart';

ApiException unknownApiResponseError({
  required String operation,
  required int statusCode,
  required dynamic body,
}) {
  return ApiException.unknown(
    extractApiErrorMessage(
      body,
      fallback: '$operation failed (status: $statusCode).',
    ),
    statusCode: statusCode,
    operation: operation,
  );
}

String extractApiErrorMessage(dynamic body, {required String fallback}) {
  if (body is Map) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
  }
  return fallback;
}
