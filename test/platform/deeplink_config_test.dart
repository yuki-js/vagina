import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/config/app_config.dart';

void main() {
  group('Deeplink platform config', () {
    test(
      'android manifest configures verified https callback app link',
      () async {
        final manifest = await File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsString();

        expect(manifest, contains('android:autoVerify="true"'));
        expect(
          manifest,
          contains('android:scheme="${AppConfig.callbackScheme}"'),
        );
        expect(
          manifest,
          contains('android:host="${AppConfig.callbackHost}"'),
        );
        expect(
          manifest,
          contains('android:pathPrefix="${AppConfig.callbackPath}"'),
        );
      },
    );

    test(
      'iOS associated domains are enabled and custom URL scheme is absent',
      () async {
        final entitlements = await File(
          'ios/Runner/Runner.entitlements',
        ).readAsString();
        final infoPlist = await File('ios/Runner/Info.plist').readAsString();

        expect(
          entitlements,
          contains('applinks:${AppConfig.callbackHost}'),
        );
        expect(infoPlist, isNot(contains('CFBundleURLTypes')));
      },
    );
  });
}
