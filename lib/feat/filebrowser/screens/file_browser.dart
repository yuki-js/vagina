import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';
import 'package:vagina/feat/filebrowser/screens/file_viewer.dart';

/// File browser screen - browse virtual filesystem with hierarchical navigation.
///
/// Each directory level is a separate screen on the Navigator stack.
/// Back navigation is handled by [Navigator.pop].
class FileBrowserScreen extends StatefulWidget {
  final String initialPath;

  const FileBrowserScreen({
    super.key,
    this.initialPath = '/',
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late final VirtualFilesystemService _fsService;
  List<String> _entries = [];
  bool _isLoading = false;
  String? _error;

  String get _path => widget.initialPath;

  @override
  void initState() {
    super.initState();
    _fsService = VirtualFilesystemService(RepositoryFactory.filesystem);
    _loadDirectory();
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _fsService.list(_path);
      if (!mounted) return;
      // Sort: directories first, then files, alphabetically within each group.
      entries.sort((a, b) {
        final aIsDir = a.endsWith('/');
        final bIsDir = b.endsWith('/');
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      setState(() {
        _entries = entries;
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
  // Navigation
  // ---------------------------------------------------------------------------

  String _absolutePath(String entryName) {
    final clean = entryName.endsWith('/')
        ? entryName.substring(0, entryName.length - 1)
        : entryName;
    return _path == '/' ? '/$clean' : '$_path/$clean';
  }

  void _openDirectory(String dirName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            FileBrowserScreen(initialPath: _absolutePath(dirName)),
      ),
    );
  }

  void _openFile(String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerScreen(filePath: _absolutePath(fileName)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action menu
  // ---------------------------------------------------------------------------

  Future<void> _showActionMenu(String entry) async {
    final isDirectory = entry.endsWith('/');
    final displayName =
        isDirectory ? entry.substring(0, entry.length - 1) : entry;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isDirectory ? Icons.folder : iconForPath(entry),
                      color: isDirectory ? Colors.amber : colorForPath(entry),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.blueGrey),
              // Actions
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                title: const Text(
                  '削除',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(entry);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(String entryName) async {
    final isDirectory = entryName.endsWith('/');
    final displayName =
        isDirectory ? entryName.substring(0, entryName.length - 1) : entryName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('$displayName を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteEntry(entryName);
    }
  }

  Future<void> _deleteEntry(String entryName) async {
    final filePath = _absolutePath(entryName);
    final isDirectory = entryName.endsWith('/');

    try {
      if (isDirectory) {
        // Delete all files within the directory recursively.
        final children = await _fsService.list(filePath, recursive: true);
        for (final child in children) {
          if (!child.endsWith('/')) {
            await _fsService.delete('$filePath/$child');
          }
        }
      } else {
        await _fsService.delete(filePath);
      }

      if (!mounted) return;
      unawaited(_loadDirectory());

      final displayName = isDirectory
          ? entryName.substring(0, entryName.length - 1)
          : entryName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除しました: $displayName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dirName = _path == '/' ? 'ファイル' : _path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(dirName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: AppTheme.lightBackgroundGradient,
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
        child: Text(
          'エラー: $_error',
          style: TextStyle(color: AppTheme.lightTextSecondary),
        ),
      );
    }

    if (_entries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, index) => _buildEntryItem(_entries[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'ファイルがありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '通話中にファイルが作成されます',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(String entry) {
    final isDirectory = entry.endsWith('/');
    final displayName =
        isDirectory ? entry.substring(0, entry.length - 1) : entry;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        color: Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        leading: isDirectory
            ? const Icon(Icons.folder, color: Colors.amber)
            : Icon(iconForPath(entry), color: colorForPath(entry)),
        title: Text(
          displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        trailing: isDirectory
            ? Icon(
                Icons.chevron_right,
                color: AppTheme.lightTextSecondary,
              )
            : null,
        onTap: isDirectory
            ? () => _openDirectory(entry)
            : () => _openFile(entry),
        onLongPress: () => _showActionMenu(entry),
      ),
    );
  }
}
