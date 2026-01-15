# VAGINA

**V**oice **AGI** **N**otepad **A**gent

ノートパッド・リアルタイム音声・汎用人工知能・Flutter アプリ。

## 特徴

- 🎤 リアルタイム音声会話
- 🤖 汎用人工知能
- 📒 ノートパッド機能でハンズフリー文書作成
- 📱 Android / iOS / Windows クロスプラットフォーム
- 🎨 スタイリッシュな UI

## スクリーンショット

(準備中)

## 必要条件

- Flutter SDK 3.27.1 (fvm 経由で管理)
- Azure OpenAI API キー (Realtime API アクセス権限付き)

### Flutter バージョン管理 (fvm)

このプロジェクトは [fvm (Flutter Version Management)](https://fvm.app/) を使用して Flutter のバージョンを管理しています。

#### fvm のインストール

```bash
# Dart がインストール済みの場合
dart pub global activate fvm

# または Homebrew (macOS/Linux)
brew tap leoafarias/fvm
brew install fvm
```

詳細は [fvm の公式ドキュメント](https://fvm.app/docs/getting_started/installation) を参照してください。

#### fvm の使用方法

```bash
# プロジェクトで指定されたバージョンの Flutter をインストール
fvm install

# fvm 経由で Flutter コマンドを実行
fvm flutter --version
fvm flutter pub get
fvm flutter run

# IDE で fvm を使用する場合
# .fvm/flutter_sdk が作成されるので、このパスを IDE に設定してください
```

> **注意**: devcontainer を使用する場合、fvm は自動的に設定されます。

## クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/yuki-js/vagina.git
cd vagina

# fvm で Flutter をインストール
fvm install

# 依存関係をインストール
fvm flutter pub get

# アプリを実行
fvm flutter run
```

### devcontainer を使用する場合

devcontainer を使用すると、fvm と Flutter 3.27.1 が自動的にセットアップされます。

```bash
# VS Code で開く
code .

# Command Palette から "Dev Containers: Reopen in Container" を選択

# devcontainer 内では fvm が設定済みなので、直接 flutter コマンドを使用可能
flutter --version
flutter pub get
flutter run
```

## API キーの設定

1. アプリを起動
2. 右上の設定アイコン (⚙️) をタップ
3. Azure OpenAI Realtime URL と API キーを入力して保存

> ⚠️ API キーは端末内のセキュアストレージに保存されます。GitHub にコミットしないでください。

## プロジェクト構造

```
vagina/
├── lib/
│   ├── main.dart              # エントリーポイント
│   ├── config/                # アプリケーション設定
│   │   └── app_config.dart    # 定数・設定値
│   ├── models/                # データモデル
│   │   ├── assistant_config.dart
│   │   ├── call_session.dart
│   │   ├── chat_message.dart
│   │   ├── notepad_tab.dart
│   │   ├── realtime_events.dart
│   │   ├── realtime_session_config.dart
│   │   └── speed_dial.dart
│   ├── services/              # ビジネスロジック・API
│   │   ├── call_service.dart  # 通話管理
│   │   ├── realtime_api_client.dart  # Azure OpenAI Realtime API
│   │   ├── websocket_service.dart
│   │   ├── audio_recorder_service.dart
│   │   ├── audio_player_service.dart
│   │   ├── notepad_service.dart
│   │   ├── tool_service.dart  # ツール管理
│   │   ├── chat/              # チャット関連
│   │   │   └── chat_message_manager.dart
│   │   └── tools/             # ビルトインツール
│   │       ├── tool_manager.dart
│   │       ├── tool_registry.dart
│   │       └── builtin/       # ドキュメント・メモリ・時刻等
│   ├── providers/             # Riverpod プロバイダー
│   │   ├── providers.dart     # 全プロバイダー定義
│   │   └── repository_providers.dart
│   ├── repositories/          # データ永続化
│   │   ├── repository_factory.dart
│   │   ├── json_call_session_repository.dart
│   │   ├── json_config_repository.dart
│   │   ├── json_memory_repository.dart
│   │   └── json_speed_dial_repository.dart
│   ├── data/                  # データストレージ実装
│   │   └── json_file_store.dart
│   ├── interfaces/            # リポジトリインターフェース
│   │   ├── key_value_store.dart
│   │   ├── config_repository.dart
│   │   └── memory_repository.dart
│   ├── screens/               # 画面UI
│   │   ├── home/              # ホーム画面（タブ）
│   │   ├── call/              # 通話画面
│   │   ├── chat/              # チャット画面
│   │   ├── notepad/           # ノートパッド画面
│   │   ├── settings/          # 設定画面
│   │   ├── oobe/              # 初回起動フロー
│   │   ├── session/           # セッション詳細
│   │   ├── speed_dial/        # スピードダイヤル設定
│   │   └── about/             # アプリについて
│   ├── components/            # 再利用可能UIコンポーネント
│   │   ├── app_scaffold.dart
│   │   ├── title_bar.dart
│   │   ├── audio_level_visualizer.dart
│   │   ├── adaptive_widgets.dart
│   │   └── ...
│   ├── theme/                 # テーマ・スタイル定義
│   │   └── app_theme.dart
│   └── utils/                 # ユーティリティ関数
│       ├── audio_utils.dart
│       ├── duration_formatter.dart
│       ├── platform_compat.dart
│       └── url_utils.dart
├── test/                      # テストコード
│   └── services/
└── docs/                      # ドキュメント
```

### アーキテクチャ概要

```
┌─────────────────────────────────────────────────┐
│              UI Layer (Screens)                 │
│  HomeScreen, CallScreen, ChatPage, NotepadPage  │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│         State Management (Riverpod)             │
│   Providers, Notifiers, StreamProviders         │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           Business Logic (Services)             │
│  CallService, RealtimeApiClient, ToolService    │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│        Data Layer (Repositories)                │
│  ConfigRepository, MemoryRepository, etc.       │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│         Storage (JsonFileStore)                 │
│  File I/O, Web localStorage                     │
└─────────────────────────────────────────────────┘
```

## ドキュメント

### アーキテクチャ・設計
- [アーキテクチャ概要](docs/ARCHITECTURE.md) - システム設計とコンポーネント
- [実装サマリー](docs/IMPLEMENTATION_SUMMARY.md) - 実装の詳細
- [開発者ガイド](docs/DEVELOPMENT.md) - 開発環境セットアップ

### 機能ドキュメント
- [PWA実装](docs/PWA_IMPLEMENTATION.md) - Progressive Web App対応
- [音声フィードバック](docs/AUDIO_FEEDBACK.md) - 通話時の音声フィードバック
- [キャラクターリファクタリング](docs/CHARACTER_REFACTORING.md) - キャラクターシステム
- [エージェント監視](docs/AGENT_COMPLIANCE.md) - AI エージェント監視システム

### API仕様
- [OpenAI Realtime API 仕様](docs/OPENAI_REALTIME_API.md) - API イベント仕様
- [Realtime イベント](docs/REALTIME_EVENTS.md) - サーバーイベント詳細

### プラットフォーム固有
- [Windows ビルドガイド](docs/WINDOWS_BUILD.md) - Windows ビルド手順
- [Windows テスト手順](docs/WINDOWS_TESTING.md) - Windows テスト方法
- [Windows 実装ノート](docs/WINDOWS_IMPLEMENTATION_NOTE.md) - Windows 固有実装
- [Windows Audio制限](docs/WINDOWS_AUDIO_LIMITATION.md) - 音声関連の制限事項

### その他
- [プライバシーポリシー](docs/PRIVACY.md) - データ取り扱い
- [WebRTC移行ガイド](docs/WEBRTC_MIGRATION_GUIDE.md) - WebRTC 対応

## コントリビューション

このプロジェクトへの貢献を歓迎します！

### 貢献方法

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

### コーディング規約

- Dart の公式スタイルガイドに従う
- `dart format` でコードを整形
- 新機能には必ずテストを追加
- コメントは英語または日本語（一貫性を保つ）
- コミットメッセージは変更内容を明確に記述

## FAQ

<details>
<summary>Q: どのAzure OpenAIモデルが必要ですか？</summary>

A: GPT-4o with Realtime API が必要です。Azure ポータルでデプロイメントを作成してください。
</details>

<details>
<summary>Q: 通話料金はかかりますか？</summary>

A: Azure OpenAI の従量課金が発生します。料金は音声入力・出力のトークン数に応じて変動します。
</details>

<details>
<summary>Q: オフラインで使用できますか？</summary>

A: いいえ、Azure OpenAI APIへの接続が必須です。
</details>

<details>
<summary>Q: iOS/Androidでビルドできません</summary>

A: プラットフォーム固有の権限設定が必要です。`AndroidManifest.xml` や `Info.plist` を確認してください。
</details>

## 技術スタック

| カテゴリ | 技術 | 用途 |
|---------|------|------|
| フレームワーク | Flutter 3.27.1 | クロスプラットフォームUI |
| 状態管理 | Riverpod 3.1.0 | 依存性注入・状態管理 |
| 音声入力 | record 6.1.2 | マイク録音 (PCM 24kHz) |
| 音声再生 | just_audio / taudio | 音声再生 (Windows対応) |
| 通信 | web_socket_channel 3.0.3 | WebSocket接続 |
| ストレージ | path_provider | ファイル保存 |
| UI | Google Fonts, Flutter Markdown | フォント・Markdown表示 |

### 主要機能

- **リアルタイム音声通話**: Azure OpenAI GPT-4o Realtime APIとの双方向音声通信
- **音声フィードバック**: 通話開始時のダイヤルトーン、終了時の「ピロン」音
- **チャット履歴**: 会話内容のテキスト表示・保存
- **ノートパッド**: AIがリアルタイムで編集可能なドキュメント
- **ツールシステム**: メモリ保存、時刻取得、計算機などのビルトインツール
- **スピードダイヤル**: カスタムキャラクター設定を保存して素早く通話開始
- **キャラクターカスタマイズ**: 絵文字・名前・音声・プロンプトをカスタマイズ
- **セッション管理**: 過去の会話履歴を保存・閲覧
- **PWA対応**: Webブラウザからアプリとしてインストール可能

## 開発

### コマンド

```bash
# 静的解析
fvm flutter analyze

# テスト実行
fvm flutter test

# コードフォーマット
dart format .

# 特定のプラットフォームでビルド
fvm flutter build apk          # Android
fvm flutter build ios          # iOS
fvm flutter build windows      # Windows

# デバッグ実行
fvm flutter run -d windows     # Windows
fvm flutter run -d chrome      # Web
```

### 開発ワークフロー

1. **機能開発**: `lib/` 配下の適切なディレクトリに実装
2. **テスト作成**: `test/` 配下に対応するテストファイルを作成
3. **静的解析**: `flutter analyze` でエラーがないことを確認
4. **フォーマット**: `dart format .` でコード整形
5. **テスト実行**: `flutter test` で全テストが通ることを確認

### トラブルシューティング

#### Windows で音声再生ができない
- `taudio` パッケージを使用しているため、Windows固有の設定が必要です
- 詳細は [Windows ビルドガイド](docs/WINDOWS_BUILD.md) を参照

#### マイクが認識されない
- Android: マニフェストファイルに録音権限が必要
- iOS: Info.plist にマイク使用許可の説明が必要
- アプリ起動時に権限リクエストが表示されます

#### API接続エラー
- Azure OpenAI のエンドポイントURLとAPIキーを確認
- ネットワーク接続を確認
- ログ画面（設定 > ログ）でエラー詳細を確認

### その他の Flutter バージョンを使いたい場合

fvm を使用すると、複数のバージョンを管理できます:

```bash
# 別のバージョンをインストール
fvm install 3.38.3

# 一時的に別のバージョンを使用
fvm use 3.38.3

# デフォルトバージョン (3.27.1) に戻す
fvm use 3.27.1
```

## ライセンス

(TBD)

## 参考

- [Azure OpenAI Realtime API](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-quickstart)
- [ANL-enpit (Web版サンプル)](https://github.com/yuki-js/ANL-enpit)
