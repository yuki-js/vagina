import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:vagina/utils/platform_compat.dart';
import 'package:vagina/services/log_service.dart';

/// Handles storage and other permissions
class PermissionManager {
  static const _tag = 'PermissionManager';

  final LogService _logService;
  int? _androidSdkVersion;

  PermissionManager({LogService? logService})
      : _logService = logService ?? LogService();

  /// Get Android SDK version
  Future<int> _getAndroidSdkVersion() async {
    if (_androidSdkVersion != null) return _androidSdkVersion!;

    if (PlatformCompat.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _androidSdkVersion = androidInfo.version.sdkInt;
      _logService.info(_tag, 'Android SDK version: $_androidSdkVersion');
      return _androidSdkVersion!;
    }
    return 0;
  }

  /// Request storage permission for writing to user's Documents directory
  Future<bool> requestStoragePermission() async {
    _logService.info(_tag, 'Requesting storage permission');

    if (PlatformCompat.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();

      if (sdkVersion >= 30) {
        // Android 11+ (API 30+): Request MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.request();
        _logService.info(
            _tag, 'Manage external storage permission status: $status');
        return status.isGranted;
      } else {
        // Android 10 and below: Request standard storage permission
        final status = await Permission.storage.request();
        _logService.info(_tag, 'Storage permission status: $status');
        return status.isGranted;
      }
    }

    return true;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    if (PlatformCompat.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();

      if (sdkVersion >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      }
      return await Permission.storage.isGranted;
    }
    return true;
  }
}
