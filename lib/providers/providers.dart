// Global providers - ONLY truly shared state across multiple unrelated screens
export 'core_providers.dart';      // notepadService, logService - used by multiple services
export 'audio_providers.dart';     // isMuted, speakerMuted - used by call_page AND control_panel
export 'ui_providers.dart';        // useCupertinoStyle - app-wide setting
export 'repository_providers.dart'; // configRepository - accessed from multiple screens
