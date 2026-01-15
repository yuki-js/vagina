# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Unified Feedback Service**: CallFeedbackService combines audio and haptic feedback
  - Cleaner API with combined `callEnded()` method
  - Replaces separate HapticService and CallAudioFeedbackService
  
- **Audio Feedback** (#98): Call lifecycle audio feedback
  - Japanese PSTN-style dial tone (400Hz pure tone) during connection
  - Descending arpeggio "piron" sound (G5→E5→C5) on call end
  - Proper error handling and resource cleanup

- **PWA Support** (#95): Progressive Web App capabilities
  - Standalone display mode
  - App shortcuts ("通話を開始")
  - Enhanced manifest.json with proper metadata
  - Service worker for basic caching
  - Permissions-Policy for clipboard write
  - Optimized meta tags for mobile/desktop

- **Character System Refactoring** (#89): Non-nullable character architecture
  - Default character is now a first-class entity
  - Visual distinction: headset icon for default, emoji for custom
  - Default character fully editable (voice, prompt, emoji) except name
  - Name field protected as identifier for all speed dials
  - Improved UI display logic in call screen
  - Backward compatibility for old sessions without speedDialId

- **App Name Configuration**: Centralized display name management
  - AppConfig.appName and AppConfig.appSubtitle constants
  - Easy rebranding without code changes
  - Codename "vagina" preserved in codebase

- **Type Safety Improvements**:
  - SpeedDial parameters now required (non-nullable) in CallPage and CallMainContent
  - Cleaner null safety throughout call flow

- **Agent Compliance System** (#93): AI agent supervision
  - Enhanced validation script with comprehensive checks
  - Mandatory CI/CD validation
  - Anti-pattern detection (WIP markers, incomplete handovers, TODOs)
  - Environment self-inspection capabilities
  - Updated agent instructions with strict requirements

- **Documentation**:
  - PWA_IMPLEMENTATION.md - Progressive Web App guide
  - AUDIO_FEEDBACK.md - Audio system documentation
  - CHARACTER_REFACTORING.md - Character system architecture
  - AGENT_COMPLIANCE.md - Agent supervision system
  - Enhanced README with new features section

- **Tests**:
  - CallAudioFeedbackService unit tests
  - SpeedDial model tests
  - CallSession model tests  
  - JsonSpeedDialRepository tests
  - Improved test coverage

### Fixed
- **Session History Error** (#96): Fixed error when loading old sessions
  - CallSession.fromJson now handles missing speedDialId field
  - Defaults to SpeedDial.defaultId for backward compatibility
  - No data migration required

### Changed
- Updated README.md with new features and documentation links
- Enhanced validation script with better error messages
- Improved error handling in CallAudioFeedbackService
- Made CI validation mandatory (no longer optional)

## [1.0.0] - 2026-01-15

### Added
- Initial release with core functionality
- Real-time voice conversation with Azure OpenAI GPT-4o
- Notepad system for hands-free document creation
- Chat history with text display
- Tool system with built-in tools (memory, time, calculator)
- Speed dial system for custom character presets
- Session management for conversation history
- Cross-platform support (Android, iOS, Windows, Web)
- OOBE (Out-of-Box Experience) flow
- Settings screen with Azure OpenAI configuration
- Dark theme for call screen
- Audio visualization
- Wakelock during calls
