import 'notepad_backend.dart';

/// Per-call dependency container.
///
/// This is intentionally minimal for PR1 and will be expanded in later PRs.
class ToolContext {
  final NotepadBackend notepadBackend;

  ToolContext({
    required this.notepadBackend,
  });
}
