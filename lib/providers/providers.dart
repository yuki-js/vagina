// Main providers file - exports all provider modules
// 
// Architecture Philosophy:
// - Providers are ONLY for truly global state that needs to be shared across multiple screens
// - Local UI state should use StatefulWidget with setState
// - Complex local state can use riverpod_annotation with scoped providers
// - This keeps the global provider layer thin and maintainable
//
// Provider Organization:
// - core_providers.dart: Core services (logging, notepad)
// - audio_providers.dart: Audio state (mute, noise reduction)
// - call_providers.dart: Call service and streams
// - config_providers.dart: Assistant configuration
// - data_providers.dart: Sessions, speed dials, notepad tabs
// - ui_providers.dart: UI preferences
// - text_agent_providers.dart: Text agent selection
// - repository_providers.dart: Config repository only

export 'core_providers.dart';
export 'audio_providers.dart';
export 'call_providers.dart';
export 'config_providers.dart';
export 'data_providers.dart';
export 'ui_providers.dart';
export 'text_agent_providers.dart';
export 'repository_providers.dart';
