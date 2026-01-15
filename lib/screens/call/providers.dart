import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Call Screen Local Providers
// ============================================================================
// These providers are scoped to the call screen and related pages.
// They should only be used within the call feature to avoid global state pollution.

/// Call screen tab index provider (local to call screen)
final callScreenTabIndexProvider = StateProvider<int>((ref) => 0);

/// Call screen pip mode provider (local to call screen)
final callScreenPipModeProvider = StateProvider<bool>((ref) => false);

/// Notepad edit mode provider (local to notepad page)
final notepadEditModeProvider = StateProvider.family<bool, String>((ref, tabId) => false);

/// Temporary edited content for notepad tab (local to notepad page)
final notepadEditContentProvider = StateProvider.family<String?, String>((ref, tabId) => null);

/// Chat scroll controller attached state (local to chat page)
final chatScrollAttachedProvider = StateProvider<bool>((ref) => true);

/// Show scroll to bottom button (local to chat page)
final showScrollToBottomProvider = StateProvider<bool>((ref) => false);
