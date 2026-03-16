import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';
import 'package:vagina/feat/call/widgets/spreadsheet/editable_spreadsheet_table.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

/// Table viewer screen - view and edit tabular data files.
class TableViewerScreen extends StatefulWidget {
  final String filePath;

  const TableViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<TableViewerScreen> createState() => _TableViewerScreenState();
}

class _TableViewerScreenState extends State<TableViewerScreen> {
  static const _saveDebounceDuration = Duration(milliseconds: 500);

  late final VirtualFilesystemService _fsService;
  VirtualFile? _file;
  TabularData? _tableData;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;

  Timer? _saveDebounce;
  TabularData? _pendingSave;

  String get _fileName => widget.filePath.split('/').last;
  String get _extension => normalizedExtensionFromPath(widget.filePath);

  @override
  void initState() {
    super.initState();
    _fsService = VirtualFilesystemService(RepositoryFactory.filesystem);
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = await _fsService.read(widget.filePath);
      if (!mounted) return;

      if (file == null) {
        setState(() {
          _error = 'ファイルが見つかりません';
          _isLoading = false;
        });
        return;
      }

      // Parse tabular data
      TabularData? tableData;
      try {
        tableData = TabularData.parse(file.content, _extension);
      } catch (e) {
        setState(() {
          _error = 'テーブルデータの解析に失敗しました: $e';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _file = file;
        _tableData = tableData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });

    // When leaving edit mode, flush any pending debounced save.
    if (!_isEditing) {
      _flushPendingSave();
    }
  }

  void _scheduleSave(TabularData newData) {
    _pendingSave = newData;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, _flushPendingSave);
  }

  Future<void> _flushPendingSave() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;

    final newData = _pendingSave;
    _pendingSave = null;
    if (newData == null || _file == null) return;

    setState(() => _isSaving = true);

    try {
      final serialized = newData.serialize(_extension);
      final updatedFile = VirtualFile(
        path: widget.filePath,
        content: serialized,
      );
      await _fsService.write(updatedFile);

      if (!mounted) return;
      setState(() {
        _file = updatedFile;
        _tableData = newData;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存しました'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              iconForPath(widget.filePath),
              color: colorForPath(widget.filePath),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fileName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_tableData != null && !_isSaving)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _toggleEdit,
              tooltip: _isEditing ? '完了' : '編集',
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: AppTheme.lightBackgroundStart,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'エラーが発生しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.lightTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_tableData == null) {
      return const Center(child: Text('テーブルデータがありません'));
    }

    if (_tableData!.columns.isEmpty) {
      return const Center(
        child: Text(
          'Empty table',
          style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
        ),
      );
    }

    return EditableSpreadsheetTable(
      data: _tableData!,
      extension: _extension,
      readOnly: !_isEditing,
      useLightTheme: true,
      onDataChanged: (newData) {
        if (_isEditing) {
          _scheduleSave(newData);
        }
      },
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
