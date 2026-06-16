class OidcCallbackPayload {
  final String code;
  final String state;

  const OidcCallbackPayload({required this.code, required this.state});

  static OidcCallbackPayload? fromUri(Uri uri) {
    final code = uri.queryParameters['code']?.trim();
    final state = uri.queryParameters['state']?.trim();
    if (code == null || code.isEmpty || state == null || state.isEmpty) {
      return null;
    }

    return OidcCallbackPayload(code: code, state: state);
  }
}
