import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

/// File info viewer screen - view file metadata and information.
class FileInfoViewerScreen extends StatefulWidget {
  final String filePath;

  const FileInfoViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<FileInfoViewerScreen> createState() => _FileInfoViewerScreenState();
}

class _FileInfoViewerScreenState extends State<FileInfoViewerScreen> {
  late final VirtualFilesystemService _fsService;
  VirtualFile? _file;
  bool _isLoading = false;
  String? _error;

  String get _fileName => widget.filePath.split('/').last;
  String get _extension => normalizedExtensionFromPath(widget.filePath);
  AppLocalizations get _l10n => AppLocalizations.of(context);

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
          _error = _l10n.fileViewerFileNotFound;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _file = file;
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildContentPreview(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final contentBytes = _file!.content.codeUnits.length;
    final lineCount = _file!.content.split('\n').length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.fileViewerInfoTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(_l10n.fileViewerInfoNameLabel, _fileName),
            _buildInfoRow(_l10n.fileViewerInfoPathLabel, widget.filePath),
            _buildInfoRow(
              _l10n.fileViewerInfoExtensionLabel,
              _extension.isNotEmpty ? _extension : _l10n.fileViewerNoExtension,
            ),
            _buildInfoRow(
                _l10n.fileViewerInfoSizeLabel, _formatFileSize(contentBytes)),
            _buildInfoRow(_l10n.fileViewerInfoLinesLabel, lineCount.toString()),
            _buildInfoRow(
              _l10n.fileViewerInfoCharactersLabel,
              _file!.content.length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppTheme.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    const maxPreviewLength = 500;
    final preview = _file!.content.length > maxPreviewLength
        ? '${_file!.content.substring(0, maxPreviewLength)}...'
        : _file!.content;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.fileViewerPreviewTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                ),
              ),
              child: SelectableText(
                preview.isEmpty ? _l10n.sessionDetailNoContent : preview,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppTheme.lightTextPrimary,
                  height: 1.5,
                ),
              ),
            ),
            if (_file!.content.length > maxPreviewLength)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _l10n.fileViewerPreviewTruncatedNote(maxPreviewLength),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
