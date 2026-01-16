import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/services/log_service.dart' as log;

part 'log_provider.g.dart';

@Riverpod(keepAlive: true)
log.LogService logService(Ref ref) {
  // Use existing singleton for backward compatibility.
  return log.logService;
}
