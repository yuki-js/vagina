import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/tabular_data.dart';
import 'spreadsheet/editable_spreadsheet_table.dart';

/// Spreadsheet content renderer with unified read-only and editable modes.
class SpreadsheetContent extends StatefulWidget {
  final String content;
  final String mimeType;
  final bool isEditing;
  final void Function(String)? onContentChanged;

  const SpreadsheetContent({
    super.key,
    required this.content,
    required this.mimeType,
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
      data = TabularData.parse(widget.content, widget.mimeType);
    } catch (e) {
      // Parse error: show error banner with raw content
      return _buildParseError(e);
    }

    if (data.columns.isEmpty) {
      return _buildEmptyTable();
    }

    // Use unified EditableSpreadsheetTable for both read-only and editable modes
    return EditableSpreadsheetTable(
      data: data,
      mimeType: widget.mimeType,
      readOnly: !widget.isEditing,
      onDataChanged: (newData) {
        if (widget.isEditing) {
          try {
            final serialized = newData.serialize(widget.mimeType);
            widget.onContentChanged?.call(serialized);
          } catch (e) {
            debugPrint('Error serializing data: $e');
          }
        }
      },
    );
  }

  /// Parse error display with raw content
  Widget _buildParseError(Object error) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.red.withValues(alpha: 0.1),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Parse error: $error',
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
  Widget _buildEmptyTable() {
    return const Center(
      child: Text(
        'Empty table',
        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}
