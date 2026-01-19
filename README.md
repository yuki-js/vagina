# VAGINA

**V**oice **AGI** **N**otepad **A**gent

ノートパッド・リアルタイム音声・汎用人工知能・Flutter アプリ。

## 特徴

- 🎤 **リアルタイム音声会話** - Azure OpenAI Realtime APIによる自然な対話
- 🤖 **汎用人工知能** - GPT-4oによる高度な推論と応答
- 📒 **ノートパッド機能** - ハンズフリー文書作成・編集
- 🧠 **テキストエージェント** - 深い分析と長文生成に特化したAIアシスタント (NEW)
- 🛠️ **強化されたツールシステム** - 音声エージェントからテキストエージェントへのクエリ機能 (NEW)
- ☎️ **プログラマティック通話制御** - AIによる自動通話終了機能 (NEW)
- 📱 **クロスプラットフォーム** - Android / iOS / Windows / Web 対応
- 🎨 **スタイリッシュな UI** - モダンなデザイン

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

## UI構造チェック

スクリーン/タブ/ペーン/セグメントの配置ルールを簡易チェックします。

```bash
python3 scripts/ui_structure_check.py --lib ./lib
```

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
│   ├── core/                  # コア機能
│   │   └── state/             # 状態管理プロバイダー
│   ├── feat/                  # 機能別ディレクトリ（Feature-first）
│   │   ├── home/              # ホーム機能
│   │   │   ├── screens/       # 画面
│   │   │   └── tabs/          # タブUI
│   │   ├── call/              # 通話機能
│   │   │   ├── screens/       # 画面
│   │   │   ├── panes/         # ペインUI（Chat/Call/Notepad）
│   │   │   ├── widgets/       # ウィジェット
│   │   │   └── state/         # 状態管理
│   │   ├── session/           # セッション機能
│   │   │   ├── screens/       # 画面
│   │   │   ├── segments/      # セグメントUI
│   │   │   ├── widgets/       # ウィジェット
│   │   │   └── state/         # 状態管理
│   │   ├── settings/          # 設定機能
│   │   ├── oobe/              # 初回起動フロー
│   │   ├── speed_dial/        # スピードダイヤル設定
│   │   └── about/             # アプリについて
│   ├── models/                # データモデル
│   ├── services/              # ビジネスロジック・API
│   │   ├── call_service.dart
│   │   ├── realtime_api_client.dart
│   │   ├── chat/              # チャット関連
│   │   ├── tools/             # ツールシステム
│   │   └── platform/          # プラットフォーム固有
│   ├── repositories/          # データ永続化
│   ├── data/                  # ストレージ実装
│   ├── interfaces/            # リポジトリインターフェース
│   ├── widgets/               # 共有UIコンポーネント
│   ├── theme/                 # テーマ定義
│   └── utils/                 # ユーティリティ
├── test/                      # テストコード
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

### ユーザー向けドキュメント
- [テキストエージェント ユーザーガイド](docs/features/text_agents.md) - テキストエージェントの使い方
- [音声エージェントツール](docs/features/voice_agent_tools.md) - 新しい4つのツールの使い方

### 開発者向けドキュメント
- [テキストエージェント アーキテクチャ](docs/development/text_agent_architecture.md) - システム設計とコンポーネント
- [ツール開発ガイド](docs/development/tool_development.md) - 新しいツールの作成方法
- [API リファレンス](docs/api/text_agent_api.md) - テキストエージェント API仕様

### その他のドキュメント
- [アーキテクチャ](docs/ARCHITECTURE.md) - 全体システム設計
- [開発者ガイド](docs/DEVELOPMENT.md) - 環境セットアップとビルド方法
- [Realtime API](docs/REALTIME_API.md) - Azure OpenAI API 仕様
- [Windows 版](docs/WINDOWS.md) - Windows ビルド・テスト
- [WebRTC 移行](docs/WEBRTC_MIGRATION_GUIDE.md) - WebRTC 対応（将来）
- [プライバシー](docs/PRIVACY.md) - データ取り扱いポリシー

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

#### 音声エージェント機能
- **リアルタイム音声通話**: Azure OpenAI GPT-4o Realtime APIとの双方向音声通信
- **音声フィードバック**: 通話開始時のダイヤルトーン、終了時の「ピロン」音
- **チャット履歴**: 会話内容のテキスト表示・保存
- **ノートパッド**: AIがリアルタイムで編集可能なドキュメント
- **スピードダイヤル**: カスタムキャラクター設定を保存して素早く通話開始
- **キャラクターカスタマイズ**: 絵文字・名前・音声・プロンプトをカスタマイズ
- **セッション管理**: 過去の会話履歴を保存・閲覧

#### テキストエージェント機能 (NEW v1.1.0)
- **専門的なAIアシスタント**: 深い分析や長文生成に特化したテキストエージェント
- **3つのレイテンシーモード**:
  - **Instant** (< 30秒): 即座の回答が必要な簡単な質問
  - **Long** (< 10分): 詳細な分析や中程度の長さのコンテンツ生成
  - **Ultra Long** (< 1時間): 包括的なリサーチや長文レポート作成
- **バックグラウンド処理**: 通話終了後も継続するジョブ実行
- **永続化されたジョブ**: アプリ再起動後も結果を取得可能
- **複数エージェント管理**: 用途別に複数のエージェントを設定可能

#### 新しいツール機能 (NEW v1.1.0)
- **end_call**: 音声エージェントがプログラマティックに通話を終了
- **query_text_agent**: 音声エージェントからテキストエージェントへクエリ
- **get_text_agent_response**: 非同期ジョブの結果を取得
- **list_available_agents**: 利用可能なテキストエージェントを一覧表示

#### その他の機能
- **ツールシステム**: メモリ保存、時刻取得、計算機などのビルトインツール
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
- 詳細は [Windows 版ガイド](docs/WINDOWS.md) を参照

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
