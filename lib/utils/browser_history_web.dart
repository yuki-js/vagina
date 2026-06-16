import 'package:web/web.dart' as web;

void clearBrowserUrlTransientParams() {
  final location = web.window.location;
  final baseUri = Uri.tryParse(web.document.baseURI);
  final basePath = (baseUri == null || baseUri.path.isEmpty)
      ? '/'
      : baseUri.path;
  final sanitized = Uri(
    scheme: location.protocol.replaceAll(':', ''),
    host: location.hostname,
    port: location.port.isEmpty ? null : int.tryParse(location.port),
    path: basePath,
  ).toString();

  web.window.history.replaceState(null, web.document.title, sanitized);
}
