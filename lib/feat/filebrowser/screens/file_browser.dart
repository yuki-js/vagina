import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/file_icon_utils.dart';
import 'package:vagina/feat/filebrowser/screens/text_viewer_screen.dart';
import 'package:vagina/feat/filebrowser/screens/table_viewer_screen.dart';
import 'package:vagina/feat/filebrowser/screens/file_info_viewer_screen.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

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

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedEntries = {};

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
  // Selection mode
  // ---------------------------------------------------------------------------

  void _enterSelectionMode(String entry) {
    setState(() {
      _isSelectionMode = true;
      _selectedEntries.add(entry);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedEntries.clear();
    });
  }

  void _toggleSelection(String entry) {
    setState(() {
      if (_selectedEntries.contains(entry)) {
        _selectedEntries.remove(entry);
        // Exit selection mode if no items are selected
        if (_selectedEntries.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedEntries.add(entry);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedEntries.addAll(_entries);
    });
  }

  void _invertSelection() {
    setState(() {
      final toSelect = _entries
          .where((entry) => !_selectedEntries.contains(entry))
          .toSet();
      final toDeselect =
          _selectedEntries.where((entry) => _entries.contains(entry)).toSet();
      _selectedEntries.removeAll(toDeselect);
      _selectedEntries.addAll(toSelect);
    });
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
    // Open with default viewer directly
    final filePath = _absolutePath(fileName);
    final extension = normalizedExtensionFromPath(filePath);
    final defaultViewer = _getDefaultViewer(extension);
    _navigateToViewer(defaultViewer, filePath);
  }

  String _getDefaultViewer(String extension) {
    final lower = extension.toLowerCase();
    final isTableFile = lower == '.v2d.csv' ||
        lower == '.v2d.json' ||
        lower == '.v2d.jsonl';

    return isTableFile ? 'table' : 'text';
  }

  void _navigateToViewer(String viewerType, String filePath) {
    Widget screen;
    switch (viewerType) {
      case 'text':
        screen = TextViewerScreen(filePath: filePath);
        break;
      case 'table':
        screen = TableViewerScreen(filePath: filePath);
        break;
      case 'info':
        screen = FileInfoViewerScreen(filePath: filePath);
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // ---------------------------------------------------------------------------
  // Selection mode actions
  // ---------------------------------------------------------------------------

  Future<void> _showRenameDialog() async {
    if (_selectedEntries.isEmpty) return;
    final entry = _selectedEntries.first;
    final isDirectory = entry.endsWith('/');
    final oldName =
        isDirectory ? entry.substring(0, entry.length - 1) : entry;

    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新しい名前',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      await _renameEntry(entry, newName);
    }
  }

  void _showFileInfo() {
    if (_selectedEntries.isEmpty) return;
    final entry = _selectedEntries.first;
    final filePath = _absolutePath(entry);

    _navigateToViewer('info', filePath);
  }

  Future<void> _renameEntry(String oldEntry, String newName) async {
    try {
      final isDirectory = oldEntry.endsWith('/');
      final oldPath = _absolutePath(oldEntry);
      final newPath =
          '$_path/$newName${isDirectory ? '/' : ''}';

      await _fsService.move(oldPath, newPath);

      if (!mounted) return;
      _exitSelectionMode();
      unawaited(_loadDirectory());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$oldEntry から $newName に変更しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('名前変更に失敗しました: $e')),
      );
    }
  }

  Future<void> _showDeleteSelectionConfirmation() async {
    if (_selectedEntries.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${_selectedEntries.length}件のアイテムを削除しますか？'),
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
      await _deleteSelectedEntries();
    }
  }

  Future<void> _deleteSelectedEntries() async {
    try {
      for (final entry in _selectedEntries) {
        final filePath = _absolutePath(entry);
        final isDirectory = entry.endsWith('/');

        if (isDirectory) {
          final children = await _fsService.list(filePath, recursive: true);
          for (final child in children) {
            if (!child.endsWith('/')) {
              await _fsService.delete('$filePath/$child');
            }
          }
        } else {
          await _fsService.delete(filePath);
        }
      }

      if (!mounted) return;
      final deletedCount = _selectedEntries.length;
      _exitSelectionMode();
      unawaited(_loadDirectory());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$deletedCount 件のアイテムを削除しました')),
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
        title: _isSelectionMode
            ? Text('${_selectedEntries.length}件選択中')
            : Text(dirName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select_all') {
                      _selectAll();
                    } else if (value == 'invert_selection') {
                      _invertSelection();
                    } else if (value == 'rename') {
                      _showRenameDialog();
                    } else if (value == 'info') {
                      _showFileInfo();
                    } else if (value == 'delete') {
                      _showDeleteSelectionConfirmation();
                    }
                  },
                  itemBuilder: (context) => [
                    if (_selectedEntries.length == 1)
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('名前変更'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (_selectedEntries.length == 1)
                      const PopupMenuItem(
                        value: 'info',
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('詳細'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'select_all',
                      child: ListTile(
                        leading: Icon(Icons.select_all),
                        title: Text('すべて選択'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'invert_selection',
                      child: ListTile(
                        leading: Icon(Icons.flip_to_back),
                        title: Text('選択を反転'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: AppTheme.errorColor),
                        title: Text(
                          '削除',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ]
            : [],
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
    final isSelected = _selectedEntries.contains(entry);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        color: isSelected && _isSelectionMode
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(entry),
              )
            : (isDirectory
                ? const Icon(Icons.folder, color: Colors.amber)
                : Icon(iconForPath(entry), color: colorForPath(entry))),
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
        onTap: _isSelectionMode
            ? () => _toggleSelection(entry)
            : (isDirectory
                ? () => _openDirectory(entry)
                : () => _openFile(entry)),
        onLongPress: _isSelectionMode
            ? null
            : () => _enterSelectionMode(entry),
      ),
    );
  }
}
