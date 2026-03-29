import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/data/permission_manager.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/repositories/repository_factory.dart';

part 'repository_providers.g.dart';

/// Holds the current app locale override language code.
///
/// A `null` value means the app should follow the system locale.
final appLocaleCodeProvider = StateProvider<String?>((ref) => null);

@Riverpod(keepAlive: true)
CallSessionRepository callSessionRepository(Ref ref) {
  return RepositoryFactory.callSessions;
}

@Riverpod(keepAlive: true)
SpeedDialRepository speedDialRepository(Ref ref) {
  return RepositoryFactory.speedDials;
}

@Riverpod(keepAlive: true)
ConfigRepository configRepository(Ref ref) {
  return RepositoryFactory.config;
}

@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) {
  return RepositoryFactory.preferences;
}

@Riverpod(keepAlive: true)
PermissionManager permissionManager(Ref ref) {
  // LogService is deprecated but still used here until Phase 2 migration
  // ignore: deprecated_member_use_from_same_package
  return PermissionManager();
}
