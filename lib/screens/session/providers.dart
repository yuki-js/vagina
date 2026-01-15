import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Session Detail Screen Local Providers
// ============================================================================
// These providers are scoped to the session detail view.

/// Selected tab in session detail (local to session detail screen)
enum SessionDetailTab { chat, notepad, info }

final sessionDetailTabProvider = StateProvider<SessionDetailTab>((ref) => SessionDetailTab.chat);

/// Share dialog visible (local to session detail screen)
final sessionShareDialogVisibleProvider = StateProvider<bool>((ref) => false);

/// Delete confirmation dialog visible (local to session detail screen)
final sessionDeleteDialogVisibleProvider = StateProvider<bool>((ref) => false);

/// Export format selection (local to session detail screen)
enum ExportFormat { markdown, json, text }

final sessionExportFormatProvider = StateProvider<ExportFormat>((ref) => ExportFormat.markdown);
