import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// UI Preferences Providers
// ============================================================================

/// Cupertinoスタイル設定のプロバイダ（Material vs Cupertino）
final useCupertinoStyleProvider = NotifierProvider<CupertinoStyleNotifier, bool>(
  CupertinoStyleNotifier.new,
);

/// Cupertinoスタイル設定の通知クラス
class CupertinoStyleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void toggle() {
    state = !state;
  }
  
  void set(bool value) {
    state = value;
  }
}
