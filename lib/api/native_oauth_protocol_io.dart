import 'dart:io';

import 'package:vagina/core/config/constants.dart';
import 'package:vagina/services/platform/platform_storage_service.dart';
import 'package:win32_registry/win32_registry.dart';

bool shouldRegisterNativeOAuthProtocol({
  required bool isWindows,
  required bool hasPackageIdentity,
}) => isWindows && !hasPackageIdentity;

Future<void> registerNativeOAuthProtocol() async {
  if (!Platform.isWindows) {
    return;
  }

  final hasPackageIdentity = await PlatformStorageService()
      .hasWindowsPackageIdentity();
  if (!shouldRegisterNativeOAuthProtocol(
    isWindows: true,
    hasPackageIdentity: hasPackageIdentity,
  )) {
    return;
  }

  final scheme = Constants.oauthNativeCallbackScheme;
  final protocolKey = Registry.currentUser.createKey(
    'Software\\Classes\\$scheme',
  );
  try {
    protocolKey.createValue(const RegistryValue.string('', 'URL:VAGINA OAuth'));
    protocolKey.createValue(const RegistryValue.string('URL Protocol', ''));

    final commandKey = protocolKey.createKey('shell\\open\\command');
    try {
      final executable = Platform.resolvedExecutable.replaceAll('"', r'\"');
      commandKey.createValue(RegistryValue.string('', '"$executable" "%1"'));
    } finally {
      commandKey.close();
    }
  } finally {
    protocolKey.close();
  }
}
