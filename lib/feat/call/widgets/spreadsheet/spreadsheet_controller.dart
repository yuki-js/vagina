import 'package:flutter/foundation.dart';
import 'package:vagina/models/tabular_data.dart';

/// スプレッドシートの編集状態を管理するコントローラー
class SpreadsheetController extends ChangeNotifier {
  TabularData _data;
  final void Function(TabularData) onDataChanged;

  SpreadsheetController({
    required TabularData data,
    required this.onDataChanged,
  }) : _data = data;

  TabularData get data => _data;

  // 選択状態
  int? selectedRow;
  int? selectedColumn;

  // 編集状態
  int? editingRow;
  int? editingColumn;
  String? editingValue;

  bool get isEditing => editingRow != null && editingColumn != null;

  bool isCellSelected(int row, int col) =>
      selectedRow == row && selectedColumn == col;

  bool isCellEditing(int row, int col) =>
      editingRow == row && editingColumn == col;

  /// セルを選択
  void selectCell(int row, int col) {
    if (isEditing) {
      commitEdit();
    }

    if (row < 0 || row >= _data.rows.length) return;
    if (col < 0 || col >= _data.columns.length) return;

    selectedRow = row;
    selectedColumn = col;
    notifyListeners();
  }

  /// 編集を開始
  void startEditing(int row, int col) {
    if (row < 0 || row >= _data.rows.length) return;
    if (col < 0 || col >= _data.columns.length) return;

    editingRow = row;
    editingColumn = col;
    selectedRow = row;
    selectedColumn = col;

    final columnName = _data.columns[col];
    final currentValue = _data.rows[row][columnName];
    editingValue = currentValue?.toString() ?? '';

    notifyListeners();
  }

  /// 編集内容を確定して保存
  Future<void> commitEdit() async {
    if (!isEditing) return;

    final row = editingRow!;
    final col = editingColumn!;
    final columnName = _data.columns[col];
    final newValue = editingValue ?? '';

    try {
      final currentValue = _data.rows[row][columnName];
      dynamic parsedValue;

      if (newValue.trim().isEmpty) {
        parsedValue = null;
      } else if (currentValue is num) {
        parsedValue = num.tryParse(newValue) ?? newValue;
      } else if (currentValue is bool) {
        final lower = newValue.toLowerCase().trim();
        parsedValue = lower == 'true' || lower == '1' || lower == 'yes';
      } else {
        parsedValue = newValue;
      }

      final newRows = List<Map<String, dynamic>>.from(_data.rows);
      newRows[row] = Map<String, dynamic>.from(newRows[row]);
      newRows[row][columnName] = parsedValue;

      final newData = TabularData(
        columns: _data.columns,
        rows: newRows,
      );

      _data = newData;
      onDataChanged(newData);

      editingRow = null;
      editingColumn = null;
      editingValue = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Error committing edit: $e');
      cancelEdit();
    }
  }

  /// 編集をキャンセル
  void cancelEdit() {
    editingRow = null;
    editingColumn = null;
    editingValue = null;
    notifyListeners();
  }

  /// データを更新（外部から）
  void updateData(TabularData newData) {
    _data = newData;

    if (selectedRow != null && selectedRow! >= newData.rows.length) {
      selectedRow = null;
      selectedColumn = null;
    }
    if (selectedColumn != null && selectedColumn! >= newData.columns.length) {
      selectedRow = null;
      selectedColumn = null;
    }

    notifyListeners();
  }
}
