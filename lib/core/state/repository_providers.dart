import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/data/permission_manager.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/repositories/repository_factory.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
CallSessionRepository callSessionRepository(Ref ref) {
  return RepositoryFactory.callSessions;
}

@Riverpod(keepAlive: true)
SpeedDialRepository speedDialRepository(Ref ref) {
  return RepositoryFactory.speedDials;
}

@Riverpod(keepAlive: true)
MemoryRepository memoryRepository(Ref ref) {
  return RepositoryFactory.memory;
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
  return PermissionManager(
    logService: ref.watch(logServiceProvider),
  );
}
