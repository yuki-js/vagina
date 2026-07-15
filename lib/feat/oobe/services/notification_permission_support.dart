import 'package:device_info_plus/device_info_plus.dart';
import 'package:vagina/utils/platform_compat.dart';

abstract interface class NotificationPermissionSupport {
  Future<bool> shouldShowNotificationPermission();
}

final class PlatformNotificationPermissionSupport
    implements NotificationPermissionSupport {
  PlatformNotificationPermissionSupport({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<bool> shouldShowNotificationPermission() async {
    if (!PlatformCompat.isAndroid) {
      return false;
    }
    final androidInfo = await _deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }
}

final class FixedNotificationPermissionSupport
    implements NotificationPermissionSupport {
  const FixedNotificationPermissionSupport(this.isSupported);

  final bool isSupported;

  @override
  Future<bool> shouldShowNotificationPermission() async => isSupported;
}
