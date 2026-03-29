import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';

/// Text viewer screen - view and edit text files.
class TextViewerScreen extends StatefulWidget {
  final String filePath;

  const TextViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  late final VirtualFilesystemService _fsService;
  VirtualFile? _file;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;
  String _editedContent = '';

  late final TextEditingController _controller;

  String get _fileName => widget.filePath.split('/').last;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _fsService = VirtualFilesystemService(RepositoryFactory.filesystem);
    _controller = TextEditingController();
    _loadFile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          _error = _l10n.fileViewerFileNotFound;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _file = file;
        _editedContent = file.content;
        _controller.text = file.content;
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
    if (_isEditing && _file != null && _editedContent != _file!.content) {
      _saveFile();
    }
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing && _file != null) {
        _editedContent = _file!.content;
        _controller.text = _editedContent;
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
        _controller.text = updatedFile.content;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.fileViewerSaveSuccess),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.fileViewerSaveFailed(e.toString()))),
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
          if (_file != null && !_isSaving)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _toggleEdit,
              tooltip: _isEditing
                  ? _l10n.callNotepadActionSave
                  : _l10n.callNotepadActionEdit,
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
                _l10n.fileViewerErrorTitle,
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

    if (_file == null) {
      return Center(child: Text(_l10n.fileViewerFileNotFound));
    }

    if (_isEditing) {
      return _buildEditor();
    } else {
      return _buildViewer();
    }
  }

  bool get _isMarkdown {
    final ext = VirtualFile(path: widget.filePath, content: '').extension;
    return ext == '.md' || ext == '.markdown';
  }

  Widget _buildViewer() {
    if (_isMarkdown) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: MarkdownBody(
          data: _file!.content.isEmpty
              ? '_${_l10n.sessionDetailNoContent}_'
              : _file!.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppTheme.lightTextPrimary,
            ),
            h1: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTextPrimary,
            ),
            h2: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTextPrimary,
            ),
            h3: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTextPrimary,
            ),
            code: TextStyle(
              backgroundColor:
                  AppTheme.lightTextSecondary.withValues(alpha: 0.1),
              color: AppTheme.primaryColor,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            blockquote: TextStyle(
              color: AppTheme.lightTextSecondary,
              fontStyle: FontStyle.italic,
            ),
            listBullet: const TextStyle(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _file!.content.isEmpty ? _l10n.sessionDetailNoContent : _file!.content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.lightTextPrimary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildEditor() {
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        onChanged: (value) => _editedContent = value,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.lightTextPrimary,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
