import 'package:flutter/material.dart';

import 'package:vagina/feat/session/widgets/historical_notepad_view.dart';
import 'package:vagina/models/call_session.dart';

/// Session detail segment - read-only notepad tabs.
class SessionDetailNotepadSegment extends StatelessWidget {
  final List<SessionNotepadTab>? notepadTabs;

  const SessionDetailNotepadSegment({
    super.key,
    required this.notepadTabs,
  });

  @override
  Widget build(BuildContext context) {
    return HistoricalNotepadView(notepadTabs: notepadTabs);
  }
}
