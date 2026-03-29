import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/tabular_data.dart';
import 'spreadsheet/editable_spreadsheet_table.dart';

/// Spreadsheet content renderer with unified read-only and editable modes.
class SpreadsheetContent extends StatefulWidget {
  final String content;
  final String extension;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const SpreadsheetContent({
    super.key,
    required this.content,
    required this.extension,
    this.isEditing = false,
    this.onContentChanged,
  });

  @override
  State<SpreadsheetContent> createState() => _SpreadsheetContentState();
}

class _SpreadsheetContentState extends State<SpreadsheetContent> {
  @override
  Widget build(BuildContext context) {
    TabularData data;
    try {
      data = TabularData.parse(widget.content, widget.extension);
    } catch (e) {
      // Parse error: show error banner with raw content
      return _buildParseError(context, e);
    }

    if (data.columns.isEmpty) {
      return _buildEmptyTable(context);
    }

    // Use unified EditableSpreadsheetTable for both read-only and editable modes
    return EditableSpreadsheetTable(
      data: data,
      extension: widget.extension,
      readOnly: !widget.isEditing,
      onDataChanged: (newData) {
        if (widget.isEditing) {
          try {
            final serialized = newData.serialize(widget.extension);
            widget.onContentChanged?.call(serialized);
          } catch (e) {
            debugPrint('Error serializing data: $e');
          }
        }
      },
    );
  }

  /// Parse error display with raw content
  Widget _buildParseError(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.red.withValues(alpha: 0.1),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              l10n.callNotepadSpreadsheetParseError(error.toString()),
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty table display
  Widget _buildEmptyTable(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Text(
        l10n.callNotepadSpreadsheetEmptyTable,
        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}
