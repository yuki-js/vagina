import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vagina/utils/platform_compat.dart';

/// Resolves durable application storage that is excluded from platform backup
/// and roaming where the supported platform provides such a facility.
class PlatformStorageService {
  static const MethodChannel _storageChannel = MethodChannel(
    'app.aoki.yuki.vagina/non_backup_storage',
  );
  static final Logger _logger = Logger('PlatformStorageService');

  final Future<String> Function()? _nativeStorageRootProvider;

  PlatformStorageService({Future<String> Function()? nativeStorageRootProvider})
    : _nativeStorageRootProvider = nativeStorageRootProvider;

  /// Returns the application storage directory used for local configuration.
  ///
  /// Android, iOS, and Windows resolve a native, device-local, non-backup root.
  /// Other native platforms retain application-support storage until an
  /// equivalent platform contract is implemented. Web storage is handled by
  /// JsonFileStore and does not use this directory.
  Future<Directory> getStorageDirectory({String? folderName}) async {
    if (kIsWeb) {
      return Directory('');
    }

    final rootPath = await _getStorageRootPath();
    final directory = Directory(
      folderName == null ? rootPath : path.join(rootPath, folderName),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _logger.info('Using non-backup app storage: ${directory.path}');
    return directory;
  }

  Future<String> getFilePath(String fileName, {String? folderName}) async {
    final directory = await getStorageDirectory(folderName: folderName);
    return path.join(directory.path, fileName);
  }

  /// Whether this Windows process is running with MSIX package identity.
  Future<bool> hasWindowsPackageIdentity() async {
    if (!PlatformCompat.isWindows) {
      return false;
    }
    return await _storageChannel.invokeMethod<bool>('hasPackageIdentity') ??
        false;
  }

  Future<String> _getStorageRootPath() async {
    final injectedProvider = _nativeStorageRootProvider;
    if (injectedProvider != null) {
      return _requirePath(await injectedProvider());
    }

    if (PlatformCompat.isAndroid ||
        PlatformCompat.isIOS ||
        PlatformCompat.isWindows) {
      final rootPath = await _storageChannel.invokeMethod<String>(
        'getNonBackupStorageRoot',
      );
      return _requirePath(rootPath);
    }

    return (await getApplicationSupportDirectory()).path;
  }

  String _requirePath(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      throw StateError('Platform returned an empty non-backup storage path.');
    }
    return normalized;
  }

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
