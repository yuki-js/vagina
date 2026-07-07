import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/config/app_config.dart';

void main() {
  group('AppConfig announcement URI resolution', () {
    test('web localhost resolves to current serving port', () {
      expect(
        AppConfig.resolveAnnouncementJsonUri(
          isWeb: true,
          isDebugMode: true,
          baseUri: Uri.parse('http://localhost:54321/'),
        ),
        Uri.parse('https://localhost:54321/announcement.json'),
      );
    });

    test('web staging domain is treated as an unknown release host', () {
      expect(
        AppConfig.resolveAnnouncementJsonUri(
          isWeb: true,
          isDebugMode: false,
          baseUri: Uri.parse('https://stg.vagina.app/'),
        ),
        Uri.parse('https://vagina.app/announcement.json'),
      );
    });

    test('web production domain resolves to production URI', () {
      expect(
        AppConfig.resolveAnnouncementJsonUri(
          isWeb: true,
          isDebugMode: false,
          baseUri: Uri.parse('https://vagina.app/'),
        ),
        Uri.parse('https://vagina.app/announcement.json'),
      );
    });

    test('native debug avoids inventing an unknown localhost port', () {
      expect(
        AppConfig.resolveAnnouncementJsonUri(isWeb: false, isDebugMode: true),
        isNull,
      );
    });

    test('native release resolves to production URI', () {
      expect(
        AppConfig.resolveAnnouncementJsonUri(isWeb: false, isDebugMode: false),
        Uri.parse('https://vagina.app/announcement.json'),
      );
    });
  });
}
