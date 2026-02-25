/// Utilities for URL parsing and manipulation
class UrlUtils {
  const UrlUtils._();

  /// Parse Azure Realtime URL to extract components
  /// Returns null if URL is invalid
  ///
  /// Expected format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
  static Map<String, String>? parseAzureRealtimeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Validate Azure OpenAI host
      if (!uri.host.endsWith('.openai.azure.com')) {
        return null;
      }

      final deployment = uri.queryParameters['deployment'];
      final apiVersion = uri.queryParameters['api-version'];

      if (deployment == null || deployment.isEmpty) {
        return null;
      }

      // Build the endpoint (base URL without path/query)
      final endpoint = '${uri.scheme}://${uri.host}';

      return {
        'endpoint': endpoint,
        'deployment': deployment,
        'apiVersion': apiVersion ?? '2024-10-01-preview',
      };
    } catch (e) {
      return null;
    }
  }

  /// Convert HTTPS URL to WSS (WebSocket Secure) URL
  static String httpsToWss(String url) {
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    }
    return url;
  }

  /// Redact sensitive query parameters from URL for logging
  static String redactSensitiveParams(String url,
      {List<String> sensitiveParams = const ['api-key', 'key', 'token']}) {
    try {
      final uri = Uri.parse(url);
      final redactedParams = Map<String, dynamic>.from(uri.queryParameters);

      for (final param in sensitiveParams) {
        if (redactedParams.containsKey(param)) {
          redactedParams[param] = '[REDACTED]';
        }
      }

      return uri
          .replace(queryParameters: redactedParams.cast<String, String>())
          .toString();
    } catch (e) {
      return url;
    }
  }
}
