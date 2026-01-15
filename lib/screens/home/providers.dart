import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Home Screen Local Providers
// ============================================================================
// These providers are scoped to the home screen and its tabs.
// They manage UI state specific to the home screen navigation.

/// Current tab index in home screen (local to home screen)
final homeScreenTabIndexProvider = StateProvider<int>((ref) => 0);

/// Speed dial search query (local to speed dial tab)
final speedDialSearchQueryProvider = StateProvider<String>((ref) => '');

/// Sessions filter (local to sessions tab)
enum SessionsFilter { all, today, thisWeek, thisMonth }

final sessionsFilterProvider = StateProvider<SessionsFilter>((ref) => SessionsFilter.all);

/// Sessions search query (local to sessions tab)
final sessionsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Tools search query (local to tools tab)
final toolsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Tools filter by category (local to tools tab)
final toolsCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Agents search query (local to agents tab)
final agentsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Show agent details panel (local to agents tab)
final showAgentDetailsPanelProvider = StateProvider<bool>((ref) => false);
