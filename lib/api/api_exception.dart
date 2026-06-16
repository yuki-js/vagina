enum ApiErrorType {
  badRequest,
  forbidden,
  notFound,
  conflict,
  serverError,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final String? operation;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.operation,
  });

  const ApiException.badRequest(
    this.message, {
    this.statusCode = 400,
    this.operation,
  }) : type = ApiErrorType.badRequest;

  const ApiException.forbidden(
    this.message, {
    this.statusCode = 403,
    this.operation,
  }) : type = ApiErrorType.forbidden;

  const ApiException.notFound(
    this.message, {
    this.statusCode = 404,
    this.operation,
  }) : type = ApiErrorType.notFound;

  const ApiException.conflict(
    this.message, {
    this.statusCode = 409,
    this.operation,
  }) : type = ApiErrorType.conflict;

  const ApiException.serverError(
    this.message, {
    this.statusCode = 500,
    this.operation,
  }) : type = ApiErrorType.serverError;

  const ApiException.unknown(
    this.message, {
    this.statusCode,
    this.operation,
  }) : type = ApiErrorType.unknown;

  @override
  String toString() => message;
}
