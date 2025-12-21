# Windows ビルドガイド

このドキュメントでは、VAGINA アプリの Windows 版ビルドについて説明します。

## 概要

Windows 版は GitHub Actions を通じて自動的にビルドされ、ビルド成果物（artifacts）としてダウンロードできます。

## CI/CD パイプライン

### ワークフロー構成

Windows CI は `.github/workflows/windows.yml` で定義されており、以下の3つのジョブで構成されています：

1. **Preprocess (Linux)** - 前処理
   - Linux 環境で実行
   - Flutter の解析 (`flutter analyze`)
   - テストの実行 (`flutter test`)
   - `.dart_tool` キャッシュの準備

2. **Build Windows (Debug)** - デバッグビルド
   - Windows 環境で実行
   - デバッグ版バイナリのビルド
   - ZIP 形式でパッケージング

3. **Build Windows (Release)** - リリースビルド
   - Windows 環境で実行
   - リリース版バイナリのビルド
   - ZIP 形式でパッケージング

### パフォーマンス最適化

Windows の GitHub Actions 環境は IO 速度が遅いため、以下の最適化を実施しています：

#### 1. Linux での前処理

プラットフォームに依存しない処理（analyze、test）を高速な Linux 環境で実行することで、Windows ビルド時間を短縮しています。

#### 2. 多段階キャッシング

以下のキャッシュを活用してビルド時間を削減：

- **Flutter SDK キャッシュ**: `subosito/flutter-action@v2` の組み込み機能
- **Pub 依存関係キャッシュ**: `~\AppData\Local\Pub\Cache` と `.dart_tool`
- **ビルド出力キャッシュ**: `build\windows` ディレクトリ
- **前処理成果物**: Linux で生成した `.dart_tool` を Windows ジョブに転送

#### 3. キャッシュキーの設計

```yaml
key: ${{ runner.os }}-flutter-build-release-${{ hashFiles('windows/**', 'lib/**', 'pubspec.lock') }}
```

- OS ごとに分離
- ビルドタイプ（debug/release）ごとに分離
- Windows 固有ファイル、Dart コード、依存関係の変更を検知

## ローカルビルド

### 前提条件

- Windows 10/11 (64-bit)
- Flutter SDK 3.27.1 以降
- Visual Studio 2022 (C++ デスクトップ開発ワークロード)
- Git

### Visual Studio のセットアップ

Windows デスクトップアプリケーションのビルドには Visual Studio の C++ コンポーネントが必要です：

1. [Visual Studio 2022 Community](https://visualstudio.microsoft.com/ja/downloads/) をダウンロード
2. インストーラーで「C++ によるデスクトップ開発」ワークロードを選択
3. インストールを完了

### ビルド手順

```bash
# リポジトリをクローン
git clone https://github.com/yuki-js/vagina.git
cd vagina

# Flutter の Windows サポートを有効化（初回のみ）
flutter config --enable-windows-desktop

# 依存関係をインストール
flutter pub get

# デバッグビルド
flutter build windows --debug

# リリースビルド
flutter build windows --release
```

### ビルド成果物の場所

- **デバッグビルド**: `build\windows\x64\runner\Debug\`
- **リリースビルド**: `build\windows\x64\runner\Release\`

各ディレクトリには以下が含まれます：
- `vagina.exe` - メインの実行ファイル
- `*.dll` - 必要な DLL ファイル（Flutter エンジン、プラグインなど）
- `data/` - アセット、フォント等のリソース

## アプリケーションの実行

ビルドされたアプリケーションは以下の方法で実行できます：

```bash
# デバッグビルドを実行
.\build\windows\x64\runner\Debug\vagina.exe

# リリースビルドを実行
.\build\windows\x64\runner\Release\vagina.exe
```

または、エクスプローラーから直接 `vagina.exe` をダブルクリックして起動できます。

## GitHub Actions からのダウンロード

1. [Actions タブ](https://github.com/yuki-js/vagina/actions) を開く
2. "Windows CI" ワークフローを選択
3. 成功したワークフロー実行を選択
4. 下部の "Artifacts" セクションから以下をダウンロード：
   - `windows-debug-build` - デバッグビルド（14日間保持）
   - `windows-release-build` - リリースビルド（30日間保持）

## 配布

### リリース版の配布方法

リリース版を配布する場合は、以下のファイルをすべて含める必要があります：

1. `vagina.exe`
2. すべての `.dll` ファイル
3. `data/` フォルダー全体

ZIP ファイルとして配布する場合：

```powershell
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath vagina-windows-release.zip
```

### 実行時の注意事項

- 初回実行時に Windows Defender SmartScreen の警告が表示される場合があります
- アプリケーションには管理者権限は不要です
- マイクの使用許可が必要です（初回起動時に確認）

## トラブルシューティング

### ビルドエラー

**「Visual Studio が見つかりません」エラー**

```
Visual Studio build tools cannot be found
```

→ Visual Studio 2022 と「C++ によるデスクトップ開発」ワークロードをインストールしてください。

**DLL エラー**

アプリケーション実行時に DLL が見つからないエラーが発生する場合：

1. すべての DLL ファイルが `.exe` と同じディレクトリにあることを確認
2. `data/` フォルダーも同じディレクトリに存在することを確認

### パフォーマンス

**ビルドが遅い**

- `flutter clean` を実行してビルドキャッシュをクリア
- 不要な依存関係を `pubspec.yaml` から削除
- SSD を使用することを推奨

## 参考資料

- [Flutter Desktop Support](https://docs.flutter.dev/desktop)
- [Building Windows Apps](https://docs.flutter.dev/platform-integration/windows/building)
- [GitHub Actions - Windows Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
