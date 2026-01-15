// Main providers file - exports all provider modules for convenience
// 
// This file has been refactored to improve organization and maintainability.
// Providers are now organized into separate modules by functionality:
// - core_providers.dart: Core services (logging, notepad)
// - audio_providers.dart: Audio recording, playback, and configuration
// - call_providers.dart: Call service and realtime API
// - config_providers.dart: API keys and assistant configuration
// - data_providers.dart: Sessions, speed dials, and notepad data
// - ui_providers.dart: UI preferences and settings
// - text_agent_providers.dart: Text agent management
// - repository_providers.dart: Repository instances

export 'core_providers.dart';
export 'audio_providers.dart';
export 'call_providers.dart';
export 'config_providers.dart';
export 'data_providers.dart';
export 'ui_providers.dart';
export 'text_agent_providers.dart';
export 'repository_providers.dart';

