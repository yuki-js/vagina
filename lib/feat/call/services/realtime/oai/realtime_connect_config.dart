/// Opaque connection configuration for the OpenAI Realtime protocol family.
///
/// The [baseUri] is treated as completely opaque. The transport never inspects
/// its contents. The [epFragment] is appended to the base path, and the scheme
/// is upgraded to `ws`/`wss` if needed.
final class OaiRealtimeConnectConfig {
  /// The opaque base URI provided by the caller.
  final Uri baseUri;

  /// The endpoint fragment appended to the base URI path.
  final String epFragment;

  /// Bearer token for the `Authorization` header.
  final String? bearerToken;

  /// Additional headers to include during the WebSocket handshake.
  final Map<String, String> extraHeaders;

  const OaiRealtimeConnectConfig({
    required this.baseUri,
    this.epFragment = '/realtime',
    this.bearerToken,
    this.extraHeaders = const <String, String>{},
  });
}

/// Resolves a WebSocket endpoint URL from an opaque base URI and endpoint
/// fragment.
Uri resolveRealtimeEndpoint(
  Uri baseUri, {
  String epFragment = '/realtime',
}) {
  final basePath = baseUri.path.endsWith('/')
      ? baseUri.path.substring(0, baseUri.path.length - 1)
      : baseUri.path;
  final fragment = epFragment.startsWith('/') ? epFragment : '/$epFragment';

  final scheme = switch (baseUri.scheme) {
    'http' => 'ws',
    'https' => 'wss',
    final value => value,
  };

  return baseUri.replace(
    scheme: scheme,
    path: '$basePath$fragment',
  );
}
