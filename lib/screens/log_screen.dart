import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/log_service.dart';

/// Screen for viewing trace logs
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<LogEntry>? _logSubscription;
  bool _autoScroll = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    // Listen to new log entries
    _logSubscription = logService.logStream.listen((entry) {
      if (mounted) {
        setState(() {});
        if (_autoScroll) {
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs() {
    final logs = logService.export();
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ログをクリップボードにコピーしました'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _clearLogs() {
    logService.clear();
    setState(() {});
  }

  List<LogEntry> get _filteredLogs {
    if (_filter.isEmpty) {
      return logService.logs;
    }
    return logService.logs.where((log) {
      return log.tag.toLowerCase().contains(_filter.toLowerCase()) ||
          log.message.toLowerCase().contains(_filter.toLowerCase()) ||
          log.level.toLowerCase().contains(_filter.toLowerCase());
    }).toList();
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return AppTheme.errorColor;
      case 'WARN':
        return AppTheme.warningColor;
      case 'WS':
        return Colors.cyan;
      case 'DEBUG':
        return Colors.grey;
      default:
        return AppTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'ログ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Auto-scroll toggle
                    IconButton(
                      icon: Icon(
                        _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                        color: _autoScroll ? AppTheme.primaryColor : AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _autoScroll = !_autoScroll;
                        });
                      },
                      tooltip: '自動スクロール',
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyLogs,
                      tooltip: 'コピー',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _clearLogs,
                      tooltip: 'クリア',
                    ),
                  ],
                ),
              ),
              
              // Filter input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'フィルター...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filter = value;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Log count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      '${logs.length} エントリ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    // Level legend
                    _buildLegend('INFO', AppTheme.textPrimary),
                    _buildLegend('WS', Colors.cyan),
                    _buildLegend('WARN', AppTheme.warningColor),
                    _buildLegend('ERR', AppTheme.errorColor),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Log list
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'ログがありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: logs.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: SelectableText(
                                log.toString(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: _getLevelColor(log.level),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
