// ============================================================================
// Main providers export file
// This file re-exports all providers from their organized locations
// for backward compatibility with existing code
// ============================================================================

// Core providers (kept in providers/ as they're used everywhere)
export 'core_providers.dart';

// Repository providers (kept in providers/ as they're infrastructure)
export 'repository_providers.dart';

// Feature-specific providers (moved to features/)
export '../features/call/providers/call_providers.dart';
export '../features/notepad/providers/notepad_providers.dart';
export '../features/session/providers/session_providers.dart';
export '../features/settings/providers/settings_providers.dart';
