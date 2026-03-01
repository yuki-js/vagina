import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/tabular_data.dart';
import 'spreadsheet_controller.dart';
import 'editable_cell.dart';

/// 編集可能なスプレッドシートテーブル
///
/// [readOnly]がtrueの場合、読み取り専用モードで表示されます。
/// [useLightTheme]がtrueの場合、ライトテーマの色を使用します。
/// [shrinkWrap]がtrueの場合、内容に応じた高さになります（外側のスクロールと統合）。
class EditableSpreadsheetTable extends StatefulWidget {
  final TabularData data;
  final String mimeType;
  final void Function(TabularData) onDataChanged;
  final bool readOnly;
  final bool useLightTheme;
  final bool shrinkWrap;

  const EditableSpreadsheetTable({
    super.key,
    required this.data,
    required this.mimeType,
    required this.onDataChanged,
    this.readOnly = false,
    this.useLightTheme = false,
    this.shrinkWrap = false,
  });

  @override
  State<EditableSpreadsheetTable> createState() =>
      _EditableSpreadsheetTableState();
}

class _EditableSpreadsheetTableState extends State<EditableSpreadsheetTable> {
  late SpreadsheetController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SpreadsheetController(
      data: widget.data,
      onDataChanged: widget.onDataChanged,
    );
  }

  @override
  void didUpdateWidget(EditableSpreadsheetTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.updateData(widget.data);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.data.columns.isEmpty) {
          return Center(
            child: Text(
              'Empty table',
              style: TextStyle(
                fontSize: 14,
                color: widget.useLightTheme
                    ? AppTheme.lightTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          );
        }

        return _buildTable();
      },
    );
  }

  Widget _buildTable() {
    final textSecondary = widget.useLightTheme
        ? AppTheme.lightTextSecondary
        : AppTheme.textSecondary;
    final textPrimary =
        widget.useLightTheme ? AppTheme.lightTextPrimary : AppTheme.textPrimary;

    // Create column widths: first column (row number) is fixed, rest are IntrinsicColumnWidth
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(50.0), // Row number column
      // All data columns use IntrinsicColumnWidth with minimum width
      for (int i = 1; i <= _controller.data.columns.length; i++)
        i: const IntrinsicColumnWidth(flex: 1.0),
    };

    final tableContent = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(
          color: textSecondary.withValues(alpha: 0.3),
          width: 1,
        ),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
            children: [
              _buildHeaderCell('#', textSecondary, isRowNumber: true),
              ..._controller.data.columns.map(
                (col) => _buildHeaderCell(col, textPrimary, isRowNumber: false),
              ),
            ],
          ),
          // Data rows
          for (int rowIndex = 0;
              rowIndex < _controller.data.rows.length;
              rowIndex++)
            TableRow(
              children: [
                _buildRowNumberCell(rowIndex + 1, textSecondary),
                for (int colIndex = 0;
                    colIndex < _controller.data.columns.length;
                    colIndex++)
                  _buildDataCell(rowIndex, colIndex),
              ],
            ),
        ],
      ),
    );

    // shrinkWrap mode: no vertical scroll wrapper
    if (widget.shrinkWrap) {
      return tableContent;
    }

    // Normal mode: wrap in vertical scroll
    return SingleChildScrollView(
      child: tableContent,
    );
  }

  Widget _buildHeaderCell(String text, Color textColor,
      {required bool isRowNumber}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: isRowNumber ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: isRowNumber ? 12 : 13,
        ),
      ),
    );
  }

  Widget _buildRowNumberCell(int rowNumber, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rowNumber',
        style: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDataCell(int rowIndex, int colIndex) {
    const cellHeight = 36.0;

    return SizedBox(
      height: cellHeight,
      child: EditableCell(
        value: _controller.data.rows[rowIndex]
            [_controller.data.columns[colIndex]],
        rowIndex: rowIndex,
        colIndex: colIndex,
        controller: _controller,
        height: cellHeight,
        readOnly: widget.readOnly,
        useLightTheme: widget.useLightTheme,
      ),
    );
  }
}
