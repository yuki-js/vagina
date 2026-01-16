import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/models/speed_dial.dart';

part 'speed_dial_providers.g.dart';

/// Speed dial list.
///
/// Refresh pattern:
/// - call `ref.invalidate(speedDialsProvider)` after create/update/delete.
@riverpod
Future<List<SpeedDial>> speedDials(Ref ref) async {
  final repo = ref.watch(speedDialRepositoryProvider);
  return repo.getAll();
}
