import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vagina/utils/platform_compat.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/data/permission_manager.dart';

/// Platform-specific storage path resolution
class PlatformStorageService {
  static const _tag = 'PlatformStorage';
  final PermissionManager _permissionManager;
  final LogService _logService;

  PlatformStorageService({
    PermissionManager? permissionManager,
    LogService? logService,
  })  : _permissionManager = permissionManager ?? PermissionManager(),
        _logService = logService ?? LogService();

  /// Get the appropriate storage directory for the platform
  /// 
  /// On Android with permissions: /storage/emulated/0/Documents/{folderName}
  /// Otherwise: Application documents directory/{folderName}
  Future<Directory> getStorageDirectory({String? folderName}) async {
    if (kIsWeb) {
      // Web doesn't use directories
      return Directory('');
    }

    Directory? directory;

    // Android-specific: Try external storage if permission granted
    if (PlatformCompat.isAndroid && folderName != null) {
      final hasPermission = await _permissionManager.hasStoragePermission();

      if (hasPermission) {
        try {
          directory = Directory('/storage/emulated/0/Documents/$folderName');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          _logService.info(_tag, 'Using Android external storage: ${directory.path}');
          return directory;
        } catch (e) {
          _logService.warn(_tag, 'Cannot access Android external storage: $e');
        }
      } else {
        _logService.info(_tag, 'Storage permission not granted, using app directory');
      }
    }

    // Fallback: Use platform-appropriate app documents directory
    directory = await getApplicationDocumentsDirectory();

    // Create subfolder if specified
    if (folderName != null) {
      directory = Directory('${directory.path}/$folderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    _logService.info(_tag, 'Using app directory: ${directory.path}');
    return directory;
  }

  /// Get platform-specific file path for a named file
  Future<String> getFilePath(String fileName, {String? folderName}) async {
    final directory = await getStorageDirectory(folderName: folderName);
    return '${directory.path}/$fileName';
  }

  /// Check if external storage is available (Android only)
  Future<bool> isExternalStorageAvailable() async {
    if (!PlatformCompat.isAndroid) return false;
    return await _permissionManager.hasStoragePermission();
  }

  /// Get platform name for logging/debugging
  String get platformName {
    if (kIsWeb) return 'Web';
    if (PlatformCompat.isAndroid) return 'Android';
    if (PlatformCompat.isIOS) return 'iOS';
    if (PlatformCompat.isWindows) return 'Windows';
    if (PlatformCompat.isMacOS) return 'macOS';
    if (PlatformCompat.isLinux) return 'Linux';
    return 'Unknown';
  }
}
