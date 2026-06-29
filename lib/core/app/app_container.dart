import 'dart:async';

import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/repositories/api_call_session_repository.dart';
import 'package:vagina/repositories/api_speed_dial_repository.dart';
import 'package:vagina/repositories/api_text_agent_model_repository.dart';
import 'package:vagina/repositories/api_text_agent_repository.dart';
import 'package:vagina/repositories/api_virtual_filesystem_repository.dart';
import 'package:vagina/repositories/api_voice_agent_repository.dart';
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
  static TextAgentRepository? _textAgentRepository;
  static TextAgentModelRepository? _textAgentModelRepository;
  static VirtualFilesystemRepository? _filesystemRepository;
  static VoiceAgentRepository? _voiceAgentRepository;
  static CallSessionRepository? _callSessionRepository;

  static AuthService? _authServiceOverride;
  static AuthCallbackCoordinator? _authCallbackCoordinatorOverride;
  static SpeedDialRepository? _speedDialRepositoryOverride;
  static TextAgentRepository? _textAgentRepositoryOverride;
  static TextAgentModelRepository? _textAgentModelRepositoryOverride;
  static VirtualFilesystemRepository? _filesystemRepositoryOverride;
  static VoiceAgentRepository? _voiceAgentRepositoryOverride;
  static CallSessionRepository? _callSessionRepositoryOverride;

  static Future<void> initialize({KeyValueStore? store}) async {
    await RepositoryFactory.initialize(store: store);
    _initialized = true;
  }

  static CallSessionRepository get callSessions {
    _ensureInitialized();
    final override = _callSessionRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _callSessionRepository ??= ApiCallSessionRepository(
      apiClient: auth.apiClient,
    );
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

  static TextAgentRepository get textAgents {
    _ensureInitialized();
    final override = _textAgentRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _textAgentRepository ??= ApiTextAgentRepository(
      apiClient: auth.apiClient,
    );
  }

  static TextAgentModelRepository get textAgentModels {
    _ensureInitialized();
    final override = _textAgentModelRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _textAgentModelRepository ??= ApiTextAgentModelRepository(
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

  static VoiceAgentRepository get voiceAgents {
    _ensureInitialized();
    final override = _voiceAgentRepositoryOverride;
    if (override != null) {
      return override;
    }
    return _voiceAgentRepository ??= ApiVoiceAgentRepository(
      apiClient: auth.apiClient,
    );
  }

  static void setOverridesForTesting({
    AuthService? authService,
    AuthCallbackCoordinator? authCallbacks,
    SpeedDialRepository? speedDials,
    TextAgentRepository? textAgents,
    TextAgentModelRepository? textAgentModels,
    VirtualFilesystemRepository? filesystem,
    VoiceAgentRepository? voiceAgents,
    CallSessionRepository? callSessions,
  }) {
    _authServiceOverride = authService;
    _authCallbackCoordinatorOverride = authCallbacks;
    _speedDialRepositoryOverride = speedDials;
    _textAgentRepositoryOverride = textAgents;
    _textAgentModelRepositoryOverride = textAgentModels;
    _filesystemRepositoryOverride = filesystem;
    _voiceAgentRepositoryOverride = voiceAgents;
    _callSessionRepositoryOverride = callSessions;
  }

  static void reset() {
    unawaited(_authCallbackCoordinator?.dispose());
    unawaited(_authCallbackCoordinatorOverride?.dispose());

    _authService = null;
    _authCallbackCoordinator = null;
    _speedDialRepository = null;
    _textAgentRepository = null;
    _textAgentModelRepository = null;
    _filesystemRepository = null;
    _voiceAgentRepository = null;
    _callSessionRepository = null;
    _authServiceOverride = null;
    _authCallbackCoordinatorOverride = null;
    _speedDialRepositoryOverride = null;
    _textAgentRepositoryOverride = null;
    _textAgentModelRepositoryOverride = null;
    _filesystemRepositoryOverride = null;
    _voiceAgentRepositoryOverride = null;
    _callSessionRepositoryOverride = null;
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
