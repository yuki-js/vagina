import 'dart:async';

import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/repositories/api_speed_dial_repository.dart';
import 'package:vagina/repositories/api_virtual_filesystem_repository.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/repositories/repository_factory.dart';

/// Application composition root.
///
/// - RepositoryFactory: local persistence repositories only.
/// - AppContainer: auth/session services + API-backed repositories.
class AppContainer {
  static bool _initialized = false;

  static AuthService? _authService;
  static AuthCallbackCoordinator? _authCallbackCoordinator;
  static SpeedDialRepository? _speedDialRepository;
  static VirtualFilesystemRepository? _filesystemRepository;

  static AuthService? _authServiceOverride;
  static AuthCallbackCoordinator? _authCallbackCoordinatorOverride;
  static SpeedDialRepository? _speedDialRepositoryOverride;
  static VirtualFilesystemRepository? _filesystemRepositoryOverride;

  static Future<void> initialize({KeyValueStore? store}) async {
    await RepositoryFactory.initialize(store: store);
    _initialized = true;
  }

  static CallSessionRepository get callSessions {
    _ensureInitialized();
    return RepositoryFactory.callSessions;
  }

  static ConfigRepository get config {
    _ensureInitialized();
    return RepositoryFactory.config;
  }

  static PreferencesRepository get preferences {
    _ensureInitialized();
    return RepositoryFactory.preferences;
  }

  static AuthService get auth {
    _ensureInitialized();
    final override = _authServiceOverride;
    if (override != null) {
      return override;
    }
    return _authService ??= AuthService(preferencesRepository: preferences);
  }

  static AuthCallbackCoordinator get authCallbacks {
    _ensureInitialized();
    final override = _authCallbackCoordinatorOverride;
    if (override != null) {
      return override;
    }
    return _authCallbackCoordinator ??= AuthCallbackCoordinator(
      authService: auth,
    );
  }

  static SpeedDialRepository get speedDials {
    _ensureInitialized();
    final override = _speedDialRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _speedDialRepository ??= ApiSpeedDialRepository(
      apiClient: auth.apiClient,
    );
  }

  static VirtualFilesystemRepository get filesystem {
    _ensureInitialized();
    final override = _filesystemRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _filesystemRepository ??= ApiVirtualFilesystemRepository(
      apiClient: auth.apiClient,
    );
  }

  static void setOverridesForTesting({
    AuthService? authService,
    AuthCallbackCoordinator? authCallbacks,
    SpeedDialRepository? speedDials,
    VirtualFilesystemRepository? filesystem,
  }) {
    _authServiceOverride = authService;
    _authCallbackCoordinatorOverride = authCallbacks;
    _speedDialRepositoryOverride = speedDials;
    _filesystemRepositoryOverride = filesystem;
  }

  static void reset() {
    unawaited(_authCallbackCoordinator?.dispose());
    unawaited(_authCallbackCoordinatorOverride?.dispose());

    _authService = null;
    _authCallbackCoordinator = null;
    _speedDialRepository = null;
    _filesystemRepository = null;
    _authServiceOverride = null;
    _authCallbackCoordinatorOverride = null;
    _speedDialRepositoryOverride = null;
    _filesystemRepositoryOverride = null;
    _initialized = false;

    RepositoryFactory.reset();
  }

  static void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    throw StateError('AppContainer not initialized. Call initialize() first.');
  }
}
