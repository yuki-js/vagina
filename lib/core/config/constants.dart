/// Product-wide constants that are fixed by app policy rather than environment.
final class Constants {
  const Constants._();

  static const String appName = 'VAGINA';
  static const String appSubtitle = 'Voice AGI Notepad Agent';

  static const int vfsDefaultMaxPathLength = 512;
  static const String vfsReservedSystemPath = '/system';

  static const String oauthCallbackUrl = 'https://vagina.app/callback';

  static const String defaultDebugApiBaseUrl = 'http://localhost:8080/api';
  static const String defaultReleaseApiBaseUrl =
      'https://vagina-api.ouchiserver.aokiapp.com/api';

  static const String announcementDevHost = 'localhost';
  static const String announcementProdUrl =
      'https://vagina.app/announcement.json';

  static const String termsOfServiceUrl = 'https://vagina.tel/terms';
  static const String privacyPolicyUrl = 'https://vagina.tel/privacy';
}
