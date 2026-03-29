import 'dart:ui';

import 'package:vagina/core/config/app_config.dart';

/// Configuration for the AI assistant
class AssistantConfig {
  /// The name of the assistant
  final String name;

  /// The system instructions for the assistant
  final String instructions;

  /// The voice to use for the assistant
  final String voice;

  /// Available voices for the assistant
  static const List<String> availableVoices = [
    'alloy',
    'echo',
    'shimmer',
  ];

  static const String _defaultInstructionsTemplateJa =
      '''あなたは「{appName}」（{appSubtitle}）という名前の音声AIアシスタントです。

あなたの特徴:
- フレンドリーで親しみやすい
- 簡潔で自然な日本語で話す
- ユーザーの思考整理を手助けする
- アイデアの記録や整理をサポートする
- 必要に応じてファイルシステム上のファイルとしてメモを管理する

ファイル運用ルール:
- 作業開始時は `fs_list` で対象パスを確認する
- 編集前に `fs_open` でファイルを開く
- 読み取りは `document_read`、編集は `document_overwrite` / `document_patch` または `spreadsheet_*` を使う
- 作業完了時は `fs_close` で保存して閉じる

あなたは音声会話を通じてユーザーをサポートします。長すぎる返答は避け、会話のリズムを大切にしてください。
''';

  static const String _defaultInstructionsTemplateEn =
      '''You are "{appName}" ({appSubtitle}), a voice AI assistant.

Your traits:
- Friendly and approachable
- Speak in concise, natural English
- Help users organize their thinking
- Support recording and organizing ideas
- Manage notes as files in the file system when needed

File handling rules:
- At the start of work, use `fs_list` to confirm the target path
- Open files with `fs_open` before editing
- Use `document_read` for reading, `document_overwrite` / `document_patch` or `spreadsheet_*` for editing
- When finished, save and close with `fs_close`

You support the user through voice conversation. Avoid overly long responses and keep a natural conversational rhythm.
''';

  /// Legacy default instructions.
  ///
  /// This remains Japanese for backward compatibility when no locale-specific
  /// default is explicitly requested.
  static String get defaultInstructions =>
      defaultInstructionsForLocale(const Locale('ja'));

  /// Returns the locale-aware default instructions template for new or reset
  /// assistant configurations.
  static String defaultInstructionsForLocale(
    Locale? locale, {
    String appName = AppConfig.appName,
    String appSubtitle = AppConfig.appSubtitle,
  }) {
    final template = locale?.languageCode == 'en'
        ? _defaultInstructionsTemplateEn
        : _defaultInstructionsTemplateJa;

    return template
        .replaceAll('{appName}', appName)
        .replaceAll('{appSubtitle}', appSubtitle);
  }

  /// Creates a default assistant configuration for the provided locale.
  factory AssistantConfig({
    String? name,
    String? instructions,
    String? voice,
    Locale? locale,
  }) {
    return AssistantConfig._(
      name: name ?? AppConfig.appName,
      instructions: instructions ?? defaultInstructionsForLocale(locale),
      voice: voice ?? AppConfig.defaultVoice,
    );
  }

  const AssistantConfig._({
    required this.name,
    required this.instructions,
    required this.voice,
  });

  AssistantConfig copyWith({
    String? name,
    String? instructions,
    String? voice,
  }) {
    return AssistantConfig._(
      name: name ?? this.name,
      instructions: instructions ?? this.instructions,
      voice: voice ?? this.voice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructions': instructions,
      'voice': voice,
    };
  }

  factory AssistantConfig.fromJson(
    Map<String, dynamic> json, {
    Locale? locale,
  }) {
    return AssistantConfig._(
      name: json['name'] as String? ?? AppConfig.appName,
      instructions: json['instructions'] as String? ??
          defaultInstructionsForLocale(locale),
      voice: json['voice'] as String? ?? AppConfig.defaultVoice,
    );
  }
}
