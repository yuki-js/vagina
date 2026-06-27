class AuthException implements Exception {
  static const String authRequiredCode = 'auth.required';
  static const String sessionExpiredCode = 'auth.session_expired';

  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  const AuthException.authRequired()
    : this('Authentication is required.', code: authRequiredCode);

  const AuthException.sessionExpired()
    : this('Authentication session expired. Please sign in again.', code: sessionExpiredCode);

  @override
  String toString() => message;
}
