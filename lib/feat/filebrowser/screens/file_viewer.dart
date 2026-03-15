import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';
import 'package:vagina/feat/filebrowser/widgets/file_content_renderer.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

/// File viewer screen - view and edit files with type-specific rendering.
///
/// Reuses the content renderers from the call screen's notepad.
class FileViewerScreen extends StatefulWidget {
  final String filePath;

  const FileViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final VirtualFilesystemService _fsService;
  VirtualFile? _file;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;
  String _editedContent = '';

  String get _fileName => widget.filePath.split('/').last;
  String get _extension => normalizedExtensionFromPath(widget.filePath);

  @override
  void initState() {
    super.initState();
    _fsService = VirtualFilesystemService(RepositoryFactory.filesystem);
    _loadFile();
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

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

      setState(() {
        _file = file;
        _editedContent = file.content;
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

  // ---------------------------------------------------------------------------
  // Edit / Save
  // ---------------------------------------------------------------------------

  void _toggleEdit() {
    if (_isEditing && _file != null && _editedContent != _file!.content) {
      // Save changes when exiting edit mode
      unawaited(_saveFile());
    }
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing && _file != null) {
        _editedContent = _file!.content;
      }
    });
  }

  Future<void> _saveFile() async {
    if (_file == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedFile = VirtualFile(
        path: widget.filePath,
        content: _editedContent,
      );
      await _fsService.write(updatedFile);

      if (!mounted) return;
      setState(() {
        _file = updatedFile;
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

  void _onContentChanged(String newContent) {
    _editedContent = newContent;
  }

  // ---------------------------------------------------------------------------
  // MIME type inference
  // ---------------------------------------------------------------------------

  String _inferMimeType() {
    final lower = _extension.toLowerCase();

    if (lower == '.v2d.csv') return 'text/csv';
    if (lower == '.v2d.json') return 'application/vagina-2d+json';
    if (lower == '.v2d.jsonl') return 'application/vagina-2d+jsonl';
    if (lower == '.md' || lower == '.markdown') return 'text/markdown';
    if (lower == '.html' || lower == '.htm') return 'text/html';

    return 'text/plain';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
          if (_file != null && !_isSaving)
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
      body: _buildBody(),
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
                style: TextStyle(color: AppTheme.lightTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_file == null) {
      return const Center(child: Text('ファイルが見つかりません'));
    }

    // Use light-theme content renderer
    return FileContentRenderer(
      key: ValueKey('$_isEditing-${widget.filePath}'),
      content: _isEditing ? _editedContent : _file!.content,
      mimeType: _inferMimeType(),
      isEditing: _isEditing,
      onContentChanged: _onContentChanged,
    );
  }
}
