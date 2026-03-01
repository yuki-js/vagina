import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'spreadsheet_controller.dart';

/// 編集可能なスプレッドシートセル
///
/// [readOnly]がtrueの場合、セルの選択と編集が無効になります。
/// [useLightTheme]がtrueの場合、ライトテーマの色を使用します。
class EditableCell extends StatefulWidget {
  final dynamic value;
  final int rowIndex;
  final int colIndex;
  final SpreadsheetController controller;
  final double height;
  final bool readOnly;
  final bool useLightTheme;

  const EditableCell({
    super.key,
    required this.value,
    required this.rowIndex,
    required this.colIndex,
    required this.controller,
    this.height = 36,
    this.readOnly = false,
    this.useLightTheme = false,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  late FocusNode _focusNode;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();

    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleControllerChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      widget.controller.commitEdit();
    }
  }

  void _handleControllerChange() {
    if (_isEditing && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isEditing) {
          _focusNode.requestFocus();
          _textController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _textController.text.length,
          );
        }
      });
    }
  }

  bool get _isSelected => widget.controller.isCellSelected(
        widget.rowIndex,
        widget.colIndex,
      );

  bool get _isEditing => widget.controller.isCellEditing(
        widget.rowIndex,
        widget.colIndex,
      );

  @override
  Widget build(BuildContext context) {
    final textSecondary = widget.useLightTheme
        ? AppTheme.lightTextSecondary
        : AppTheme.textSecondary;
    final surfaceColor = widget.useLightTheme
        ? AppTheme.lightSurfaceColor
        : AppTheme.surfaceColor;

    return GestureDetector(
      onTap: () {
        widget.controller.selectCell(widget.rowIndex, widget.colIndex);
      },
      onDoubleTap: widget.readOnly
          ? null
          : () {
              widget.controller.startEditing(widget.rowIndex, widget.colIndex);
            },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isSelected
                ? AppTheme.primaryColor
                : textSecondary.withValues(alpha: 0.3),
            width: _isSelected ? 1.5 : 0.5,
          ),
          color: (!widget.readOnly && _isEditing)
              ? surfaceColor.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.centerLeft,
        child:
            (!widget.readOnly && _isEditing) ? _buildEditor() : _buildLabel(),
      ),
    );
  }

  Widget _buildEditor() {
    final editingValue = widget.controller.editingValue ?? '';
    if (_textController.text != editingValue) {
      _textController.text = editingValue;
    }

    final textPrimary =
        widget.useLightTheme ? AppTheme.lightTextPrimary : AppTheme.textPrimary;

    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      style: TextStyle(
        fontSize: 13,
        color: textPrimary,
      ),
      decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          isDense: true,
          filled: false,
          visualDensity: VisualDensity.standard),
      onChanged: (value) {
        widget.controller.editingValue = value;
      },
      onSubmitted: (_) async {
        await widget.controller.commitEdit();
        if (widget.controller.selectedRow != null &&
            widget.controller.selectedColumn != null) {
          widget.controller.startEditing(
            widget.controller.selectedRow!,
            widget.controller.selectedColumn!,
          );
        }
      },
    );
  }

  Widget _buildLabel() {
    final displayValue = widget.value?.toString() ?? '';
    final textPrimary =
        widget.useLightTheme ? AppTheme.lightTextPrimary : AppTheme.textPrimary;
    final textSecondary = widget.useLightTheme
        ? AppTheme.lightTextSecondary
        : AppTheme.textSecondary;

    return Text(
      displayValue,
      style: TextStyle(
        fontSize: 13,
        color: widget.value == null ? textSecondary : textPrimary,
        fontStyle: widget.value == null ? FontStyle.italic : FontStyle.normal,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
