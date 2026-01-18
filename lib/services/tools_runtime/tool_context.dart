import 'package:vagina/services/notepad_service.dart';

/// Per-call dependency container.
///
/// This is intentionally minimal and can be expanded later.
class ToolContext {
  /// Allows tools to access and mutate the current notepad state.
  ///
  /// This is Flutter-free.
  final NotepadService notepadService;

  ToolContext({
    required this.notepadService,
  });
}
