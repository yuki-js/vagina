import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repository_factory.dart';
import '../interfaces/call_session_repository.dart';
import '../interfaces/speed_dial_repository.dart';
import '../interfaces/memory_repository.dart';
import '../interfaces/config_repository.dart';
import '../data/permission_manager.dart';

/// Provider for CallSessionRepository
final callSessionRepositoryProvider = Provider<CallSessionRepository>((ref) {
  return RepositoryFactory.callSessions;
});

/// Provider for SpeedDialRepository
final speedDialRepositoryProvider = Provider<SpeedDialRepository>((ref) {
  return RepositoryFactory.speedDials;
});

/// Provider for MemoryRepository
final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return RepositoryFactory.memory;
});

/// Provider for ConfigRepository
final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return RepositoryFactory.config;
});

/// Provider for PermissionManager
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  return PermissionManager();
});
