import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notepad_service.dart';
import '../services/log_service.dart';

// ============================================================================
// Core Service Providers
// ============================================================================

/// ログサービスのプロバイダ
final logServiceProvider = Provider<LogService>((ref) {
  return logService; // Use existing singleton for backward compatibility
});

/// ノートパッドサービスのプロバイダ
final notepadServiceProvider = Provider<NotepadService>((ref) {
  final service = NotepadService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
