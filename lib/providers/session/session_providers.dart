import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/call_session.dart';
import '../../models/speed_dial.dart';
import '../../repositories/repository_factory.dart';

// ============================================================================
// スピードダイヤルプロバイダ
// ============================================================================

/// スピードダイヤルのプロバイダ（リポジトリ使用）
final speedDialsProvider = FutureProvider<List<SpeedDial>>((ref) async {
  return await RepositoryFactory.speedDials.getAll();
});

/// スピードダイヤル更新トリガーのプロバイダ
final speedDialsRefreshProvider =
    NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

/// 自動更新スピードダイヤルのプロバイダ（リポジトリ使用）
final refreshableSpeedDialsProvider =
    FutureProvider<List<SpeedDial>>((ref) async {
  // 更新トリガーを監視
  ref.watch(speedDialsRefreshProvider);
  return await RepositoryFactory.speedDials.getAll();
});

// ============================================================================
// セッション履歴プロバイダ
// ============================================================================

/// セッション履歴のプロバイダ（リポジトリ使用）
final callSessionsProvider = FutureProvider<List<CallSession>>((ref) async {
  return await RepositoryFactory.callSessions.getAll();
});

/// セッション履歴更新トリガーのプロバイダ
final callSessionsRefreshProvider =
    NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

/// 自動更新セッション履歴のプロバイダ（リポジトリ使用）
final refreshableCallSessionsProvider =
    FutureProvider<List<CallSession>>((ref) async {
  // 更新トリガーを監視
  ref.watch(callSessionsRefreshProvider);
  return await RepositoryFactory.callSessions.getAll();
});

/// シンプルな更新通知クラス
class RefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state++;
  }
}
