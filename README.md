# VAGINA

**V**oice **AGI** as **N**ative **A**pp

Azure OpenAI Realtime API を使用したリアルタイム音声 AI アシスタント Flutter アプリ。

## 特徴

- 🎤 リアルタイム音声会話
- 🤖 Azure OpenAI GPT-4o Realtime API 連携
- 📱 Android / iOS / Windows クロスプラットフォーム
- 🔒 セキュアな API キー管理
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
│   ├── main.dart          # エントリーポイント
│   ├── config/            # アプリ設定
│   ├── models/            # データモデル
│   ├── services/          # ビジネスロジック・API
│   ├── providers/         # Riverpod プロバイダー
│   ├── screens/           # 画面
│   │   └── components/    # 画面コンポーネント
│   ├── widgets/           # 再利用可能ウィジェット
│   └── theme/             # テーマ定義
└── docs/                  # ドキュメント
```

## ドキュメント

- [開発者ガイド](docs/DEVELOPMENT.md)
- [アーキテクチャ](docs/ARCHITECTURE.md)
- [OpenAI Realtime API 仕様](docs/OPENAI_REALTIME_API.md)
- [プライバシーポリシー](docs/PRIVACY.md)

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フレームワーク | Flutter |
| 状態管理 | Riverpod |
| 音声入力 | record |
| 音声再生 | just_audio |
| 通信 | web_socket_channel |
| セキュリティ | flutter_secure_storage |

## 開発

```bash
# 静的解析
fvm flutter analyze

# テスト
fvm flutter test

# フォーマット
dart format .
```

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
