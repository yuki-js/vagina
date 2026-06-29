import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/models/call_session.dart';

part 'session_history_providers.g.dart';

const int sessionHistoryPageSize = 30;

@riverpod
Future<List<CallSession>> callSessions(Ref ref) async {
  final repo = AppContainer.callSessions;
  final page = await repo.list(limit: sessionHistoryPageSize);
  return page.items;
}

@riverpod
Future<CallSession?> sessionDetail(Ref ref, String sessionId) {
  return AppContainer.callSessions.getById(sessionId);
}

@riverpod
class SessionHistoryController extends _$SessionHistoryController {
  @visibleForTesting
  int pageSize = sessionHistoryPageSize;

  bool _isLoadingFirstPage = false;

  @override
  SessionHistoryState build() {
    unawaited(Future<void>.microtask(loadFirstPage));
    return const SessionHistoryState(isInitialLoading: true);
  }

  Future<void> loadFirstPage() async {
    if (_isLoadingFirstPage ||
        (state.isInitialLoading && state.items.isNotEmpty)) {
      return;
    }

    _isLoadingFirstPage = true;
    state = state.copyWith(
      isInitialLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearNextCursor: true,
    );

    try {
      final page = await AppContainer.callSessions.list(limit: pageSize);
      state = SessionHistoryState(
        items: page.items,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      state = state.copyWith(
        isInitialLoading: false,
        isLoadingMore: false,
        error: error,
      );
    } finally {
      _isLoadingFirstPage = false;
    }
  }

  Future<void> refresh() => loadFirstPage();

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isInitialLoading) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await AppContainer.callSessions.list(
        cursor: cursor,
        limit: pageSize,
      );
      state = SessionHistoryState(
        items: <CallSession>[...state.items, ...page.items],
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> bulkDelete(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    await AppContainer.callSessions.bulkDelete(ids);
    final idSet = ids.toSet();
    state = state.copyWith(
      items: state.items
          .where((session) => !idSet.contains(session.id))
          .toList(growable: false),
      clearError: true,
    );
  }
}

@visibleForTesting
class SessionHistoryState {
  final List<CallSession> items;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final Object? error;

  const SessionHistoryState({
    this.items = const <CallSession>[],
    this.nextCursor,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  bool get hasError => error != null;

  SessionHistoryState copyWith({
    List<CallSession>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) {
    return SessionHistoryState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
