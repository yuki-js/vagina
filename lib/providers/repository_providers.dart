import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/data/permission_manager.dart';
import 'providers.dart'; // For logServiceProvider

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
  return PermissionManager(
    logService: ref.read(logServiceProvider),
  );
});
