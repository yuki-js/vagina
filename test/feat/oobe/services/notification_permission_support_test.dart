import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/oobe/services/notification_permission_support.dart';

void main() {
  test(
    'supported platform condition shows optional notification item',
    () async {
      const support = FixedNotificationPermissionSupport(true);

      expect(await support.shouldShowNotificationPermission(), isTrue);
    },
  );

  test(
    'unsupported platform condition hides optional notification item',
    () async {
      const support = FixedNotificationPermissionSupport(false);

      expect(await support.shouldShowNotificationPermission(), isFalse);
    },
  );
}
