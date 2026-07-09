import 'package:flutter/foundation.dart';
import 'package:vagina/core/config/constants.dart';

/// Application configuration.
class AppConfig {
  const AppConfig._();

  static String resolveApiBaseUrl({required bool isDebugMode}) {
    return isDebugMode
        ? Constants.defaultDebugApiBaseUrl
        : Constants.defaultReleaseApiBaseUrl;
  }

  /// Parsed announcement endpoint URI, or `null` when not configured.
  static Uri? get announcementJsonUri {
    return resolveAnnouncementJsonUri(
      isWeb: kIsWeb,
      isDebugMode: kDebugMode,
      baseUri: Uri.base,
    );
  }

  /// Resolves the announcement endpoint URI.
  ///
  /// Web builds infer dev/prod from the serving origin. Native builds use
  /// debug/release because there is no serving origin; native debug intentionally
  /// returns `null` instead of inventing a localhost port that may not exist.
  static Uri? resolveAnnouncementJsonUri({
    required bool isWeb,
    required bool isDebugMode,
    Uri? baseUri,
  }) {
    if (isWeb) {
      final currentBaseUri = baseUri ?? Uri.base;
      final host = currentBaseUri.host.toLowerCase();
      if (_isLocalhost(host)) {
        return Uri(
          scheme: 'https',
          host: host,
          port: currentBaseUri.hasPort ? currentBaseUri.port : null,
          path: '/announcement.json',
        );
      }
      if (host == 'vagina.app') {
        return Uri.parse(Constants.announcementProdUrl);
      }
      return isDebugMode ? null : Uri.parse(Constants.announcementProdUrl);
    }

    if (isDebugMode) {
      return null;
    }
    return Uri.parse(Constants.announcementProdUrl);
  }

  static bool _isLocalhost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost');
  }
}
