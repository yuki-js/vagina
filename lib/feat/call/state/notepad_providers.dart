import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/services/notepad_service.dart';

part 'notepad_providers.g.dart';

@riverpod
NotepadService notepadService(Ref ref) {
  final service = NotepadService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
