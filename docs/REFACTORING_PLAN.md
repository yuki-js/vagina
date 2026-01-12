# Refactoring Plan

This document outlines the technical debt identified during codebase analysis and the refactoring strategy.

## Completed Refactorings

### ✅ 1. README Complete Rewrite (Commit: 8b6e620)
**Problem:** README had incorrect directory structure references and lacked comprehensive documentation.

**Solution:**
- Updated project structure to reflect actual directories
- Added architecture diagram showing layer separation
- Expanded technology stack with versions and purposes
- Added troubleshooting, FAQ, and contribution sections

**Impact:** New developers can now quickly understand the codebase structure.

---

### ✅ 2. Utils.dart Enhancement (Commit: 4d12564)
**Problem:** `utils.dart` was just an export file with no implementation.

**Solution:**
- Added 20+ utility functions:
  - ID generation with timestamp+random
  - Safe JSON parsing
  - String manipulation (truncate, capitalize, camelCase/snake_case conversion)
  - Safe division and clamping
  - Byte formatting
  - Deep copy for Map/List
  - Retry with exponential backoff
- Created comprehensive test suite (18 tests, all passing)

**Impact:** Reduced code duplication across the codebase with reusable utilities.

---

### ✅ 3. Standardized Error Handling (Commit: 5e8665d)
**Problem:** Inconsistent error handling - mix of throw/log/stream patterns across codebase.

**Solution:**
- Created typed error hierarchy:
  - `NetworkError` - API/connectivity issues
  - `AudioError` - Microphone/speaker issues
  - `StorageError` - File I/O issues
  - `ConfigurationError` - Settings issues
  - `ValidationError` - Input validation issues
- `ErrorHandler` utility with:
  - `handleAsync()` - Wraps async operations
  - `handleSync()` - Wraps sync operations
  - Automatic error categorization
  - Japanese user-friendly messages
- 16 tests covering all error types

**Impact:** 
- Consistent error handling pattern across the app
- Better error messages for users
- Easier testing with typed errors

---

## Remaining Refactorings

### 📋 4. Split Monolithic Files
**Problem:** Large files violate Single Responsibility Principle
- `RealtimeApiClient` (1060 lines)
- `CallService` (560 lines)
- `realtime_events.dart` (525 lines)

**Proposed Solution:**

#### RealtimeApiClient
Split into:
- `lib/services/realtime/realtime_api_client.dart` - Main client
- `lib/services/realtime/event_handlers/` - Separate handlers for each event category
  - `session_event_handler.dart`
  - `conversation_event_handler.dart`
  - `audio_event_handler.dart`
  - `response_event_handler.dart`
- `lib/services/realtime/stream_controllers.dart` - Stream management

#### CallService
Split into:
- `lib/services/call/call_service.dart` - Main orchestrator
- `lib/services/call/call_state_manager.dart` - State management
- `lib/services/call/audio_stream_handler.dart` - Audio streaming logic
- `lib/services/call/session_manager.dart` - Session save/load logic

#### realtime_events.dart
Split into:
- `lib/models/realtime/event_types.dart` - Enums only
- `lib/models/realtime/client_events.dart` - Client event models
- `lib/models/realtime/server_events.dart` - Server event models
- `lib/models/realtime/session_models.dart` - Session/Conversation/Response models

**Effort:** High (2-3 days)
**Risk:** Medium (many imports need updating)
**Benefit:** Better code organization, easier to understand and maintain

---

### 📋 5. Platform-Specific Code Consolidation
**Problem:** Platform-specific logic scattered across files
- `audio_player_service_windows.dart` exists separately
- `json_file_store.dart` has Android-specific hardcoded paths
- `platform_compat.dart` provides detection but logic is dispersed

**Proposed Solution:**
- Create `lib/services/platform/` directory:
  - `platform_audio_service.dart` - Factory for platform-specific audio
  - `platform_storage_service.dart` - Platform-specific storage paths
- Update `platform_compat.dart` to include more helpers
- Consolidate all platform checks to single locations

**Effort:** Medium (1-2 days)
**Risk:** Low
**Benefit:** Easier to add new platforms, centralized platform logic

---

### 📋 6. Remove Global Singleton LogService
**Problem:** `logService` is a global variable, violates dependency injection

**Proposed Solution:**
- Add `LogService` as parameter to all service constructors
- Update Riverpod providers to inject LogService
- Create `LogService` provider in `providers.dart`
- Update ~100 usages across codebase

**Effort:** Very High (3-4 days)
**Risk:** High (touches many files)
**Benefit:** Better testability, follows dependency injection pattern

**Status:** Deferred - too high effort for current sprint

---

### 📋 7. Add Test Coverage
**Problem:** Only 7 test files, core business logic untested

**Priority Tests Needed:**
1. `CallService` - Call lifecycle, state management
2. `RealtimeApiClient` - Event handling, connection management
3. `ToolManager` - Tool execution, registration
4. `NotepadService` - Tab management, content updates
5. `JsonFileStore` - File I/O, caching

**Proposed Approach:**
- Create mock providers for testing
- Use `flutter_test` and `mockito` for mocking
- Aim for 70% coverage on business logic

**Effort:** High (2-3 days)
**Risk:** Low
**Benefit:** Confidence in refactoring, catch bugs early

---

## Prioritization Matrix

| Task | Impact | Effort | Risk | Priority |
|------|--------|--------|------|----------|
| README Rewrite | High | Low | None | ✅ Done |
| Utils Enhancement | Medium | Low | None | ✅ Done |
| Error Handling | High | Medium | Low | ✅ Done |
| Split Files | Medium | High | Medium | Next |
| Platform Consolidation | Medium | Medium | Low | Medium |
| LogService DI | Low | Very High | High | Deferred |
| Test Coverage | High | High | Low | High |

---

## Recommendations

1. **Continue with file splitting** - Start with `realtime_events.dart` (easiest) to build confidence
2. **Add tests incrementally** - Write tests as you refactor to ensure correctness
3. **Platform consolidation** - Good medium-term goal after file splitting
4. **Defer LogService DI** - Too risky and high-effort for current state

## Implementation Notes

- All refactorings maintain backward compatibility
- Tests must pass after each refactoring
- Commit frequently with clear messages
- Update documentation as you go

---

Last Updated: 2026-01-12
