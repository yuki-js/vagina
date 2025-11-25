# 開発者ガイド

## 前提条件

- Flutter SDK (3.10.0 以上)
- Dart SDK (3.10.0 以上)
- Android Studio または VS Code (Flutter 拡張機能付き)
- Xcode (iOS 開発の場合)
- Git

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/yuki-js/vagina.git
cd vagina
```

### 2. 依存関係のインストール

```bash
flutter pub get
```

### 3. 環境設定

```bash
cp .env.example .env
```

`.env` ファイルを編集して必要な設定を行います。

> ⚠️ `.env` ファイルには機密情報が含まれる可能性があります。絶対にコミットしないでください。

### 4. IDE 設定

#### VS Code

推奨拡張機能:
- Dart
- Flutter
- Flutter Riverpod Snippets

#### Android Studio

プラグイン:
- Flutter
- Dart

## ビルド & 実行

### 開発ビルド

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# すべてのデバイス一覧
flutter devices
```

### リリースビルド

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## コード品質

### 静的解析

```bash
flutter analyze
```

### フォーマット

```bash
dart format .
```

### テスト

```bash
# 全テスト実行
flutter test

# カバレッジ付き
flutter test --coverage
```

## プロジェクト構造

```
vagina/
├── lib/
│   └── main.dart           # アプリエントリーポイント
├── packages/
│   ├── core/               # 共通ロジック
│   ├── audio/              # 音声処理
│   ├── realtime_client/    # API 通信
│   ├── assistant_model/    # AI 設定
│   ├── screens/            # 画面
│   └── ui/                 # UI コンポーネント
├── test/                   # テスト
├── android/                # Android 固有設定
├── ios/                    # iOS 固有設定
└── docs/                   # ドキュメント
```

## ローカルパッケージの開発

各パッケージは独立して開発・テストできます：

```bash
cd packages/core
flutter pub get
flutter test
```

パッケージ間の依存関係は `pubspec.yaml` で `path:` 指定しています：

```yaml
dependencies:
  vagina_core:
    path: packages/core
```

## API キーの設定

アプリ内の設定画面から OpenAI API キーを入力します。キーは端末内のセキュアストレージに保存され、サーバーには送信されません。

### API キーの取得方法

1. [OpenAI Platform](https://platform.openai.com/) にアクセス
2. API Keys セクションで新しいキーを作成
3. アプリの設定画面にキーを入力

## トラブルシューティング

### マイク権限エラー

Android の場合、`android/app/src/main/AndroidManifest.xml` に権限が追加されていることを確認：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

iOS の場合、`ios/Runner/Info.plist` に説明が追加されていることを確認：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Voice input for AI assistant</string>
```

### ビルドエラー

```bash
# クリーンビルド
flutter clean
flutter pub get
flutter run
```

### 依存関係の問題

```bash
flutter pub upgrade
```

## コントリビューション

1. 機能ブランチを作成: `git checkout -b feature/amazing-feature`
2. 変更をコミット: `git commit -m 'Add amazing feature'`
3. プッシュ: `git push origin feature/amazing-feature`
4. Pull Request を作成

### コミットメッセージ規約

```
<type>(<scope>): <subject>

<body>

<footer>
```

タイプ:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみ
- `style`: コードスタイル
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: ビルド・設定変更

## 参考リンク

- [Flutter 公式ドキュメント](https://docs.flutter.dev/)
- [Riverpod ドキュメント](https://riverpod.dev/)
- [OpenAI Realtime API](https://platform.openai.com/docs/guides/realtime)
- [アーキテクチャガイド](./ARCHITECTURE.md)
- [API 仕様書](./OPENAI_REALTIME_API.md)
