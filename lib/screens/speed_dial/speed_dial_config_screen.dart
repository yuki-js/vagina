import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../home/providers.dart';
import '../../providers/core_providers.dart';
import '../../models/speed_dial.dart';
import '../../components/common/emoji_picker.dart';
import '../../repositories/repository_factory.dart';

/// Speed dial configuration screen
/// Accessed from speed dial tab when tapping on a speed dial
class SpeedDialConfigScreen extends ConsumerStatefulWidget {
  final String? speedDialId; // null for new speed dial
  final SpeedDial? speedDial; // null for new speed dial

  const SpeedDialConfigScreen({
    super.key,
    this.speedDialId,
    this.speedDial,
  });

  @override
  ConsumerState<SpeedDialConfigScreen> createState() => _SpeedDialConfigScreenState();
}

class _SpeedDialConfigScreenState extends ConsumerState<SpeedDialConfigScreen> {
  late TextEditingController _nameController;
  late TextEditingController _instructionsController;
  late String _selectedVoice;
  late String _selectedEmoji;
  bool _isNewSpeedDial = false;

  @override
  void initState() {
    super.initState();
    _isNewSpeedDial = widget.speedDial == null;
    
    if (_isNewSpeedDial) {
      _nameController = TextEditingController();
      _instructionsController = TextEditingController();
      _selectedVoice = 'alloy';
      _selectedEmoji = '⭐';
    } else {
      _nameController = TextEditingController(text: widget.speedDial!.name);
      _instructionsController = TextEditingController(text: widget.speedDial!.systemPrompt);
      _selectedVoice = widget.speedDial!.voice;
      _selectedEmoji = widget.speedDial!.iconEmoji ?? '⭐';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectEmoji() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: EmojiPicker(
            selectedEmoji: _selectedEmoji,
            onEmojiSelected: (emoji) {
              setState(() {
                _selectedEmoji = emoji;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    if (_instructionsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('システムプロンプトを入力してください')),
      );
      return;
    }

    final speedDialRepo = RepositoryFactory.speedDials;
    final speedDial = SpeedDial(
      id: _isNewSpeedDial 
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.speedDial!.id,
      name: _nameController.text,
      systemPrompt: _instructionsController.text,
      voice: _selectedVoice,
      iconEmoji: _selectedEmoji,
      createdAt: _isNewSpeedDial ? DateTime.now() : widget.speedDial!.createdAt,
    );

    if (_isNewSpeedDial) {
      await speedDialRepo.save(speedDial);
    } else {
      await speedDialRepo.update(speedDial);
    }

    ref.invalidate(refreshableSpeedDialsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNewSpeedDial ? 'スピードダイヤルを追加しました' : 'スピードダイヤルを更新しました'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteSpeedDial() async {
    if (_isNewSpeedDial) return;
    
    // Prevent deletion of default speed dial
    if (widget.speedDial!.id == SpeedDial.defaultId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デフォルトのスピードダイヤルは削除できません')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このスピードダイヤルを削除しますか?'),
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
      await RepositoryFactory.speedDials.delete(widget.speedDial!.id);
      ref.invalidate(refreshableSpeedDialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isNewSpeedDial ? 'スピードダイヤルを追加' : 'スピードダイヤルを編集'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.lightTextPrimary,
        elevation: 0,
        actions: [
          // Hide delete button for default speed dial
          if (!_isNewSpeedDial && widget.speedDial!.id != SpeedDial.defaultId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSpeedDial,
              color: AppTheme.errorColor,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfiguration,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Emoji selection
            Card(
              child: InkWell(
                onTap: _selectEmoji,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'アイコン',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _selectedEmoji,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'タップして変更',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '名前',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      enabled: _isNewSpeedDial || widget.speedDial!.id != SpeedDial.defaultId, // Disable for default speed dial
                      decoration: InputDecoration(
                        hintText: '例: アシスタント',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        helperText: (!_isNewSpeedDial && widget.speedDial!.id == SpeedDial.defaultId) 
                            ? 'デフォルトのスピードダイヤルは名前を変更できません' 
                            : null,
                      ),
                      style: const TextStyle(color: AppTheme.lightTextPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Voice selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '音声選択',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedVoice,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: const [
                        DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                        DropdownMenuItem(value: 'echo', child: Text('Echo')),
                        DropdownMenuItem(value: 'shimmer', child: Text('Shimmer')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedVoice = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // System instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'システムプロンプト',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'キャラクターの振る舞いや性格を設定',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _instructionsController,
                      decoration: InputDecoration(
                        hintText: '例: あなたは親切なアシスタントです',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: const TextStyle(color: AppTheme.lightTextPrimary),
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Save button
            ElevatedButton(
              onPressed: _saveConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isNewSpeedDial ? '追加' : '保存',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
