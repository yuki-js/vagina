import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/log_service.dart';

// ============================================================================
// コアプロバイダ - 他の多くのプロバイダから依存されるもの
// ============================================================================

/// ログサービスのプロバイダ
final logServiceProvider = Provider<LogService>((ref) {
  return logService; // Use existing singleton for backward compatibility
});
