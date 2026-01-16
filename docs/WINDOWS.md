# Windows 版ガイド

VAGINA アプリの Windows 版ビルド、テスト、既知の問題について説明します。

## ビルド

### 前提条件

- Windows 10/11 (64-bit)
- Flutter SDK 3.27.1 以降
- Visual Studio 2022 (C++ デスクトップ開発ワークロード)
- Git

### Visual Studio のセットアップ

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

### ビルド成果物

- **デバッグ**: `build\windows\x64\runner\Debug\`
- **リリース**: `build\windows\x64\runner\Release\`

各ディレクトリには以下が含まれます：
- `vagina.exe` - 実行ファイル
- `*.dll` - 必要な DLL ファイル
- `data/` - アセット、フォント等

### GitHub Actions からのダウンロード

1. [Actions タブ](https://github.com/yuki-js/vagina/actions) を開く
2. "Windows CI" ワークフローを選択
3. 成功したビルドの Artifacts からダウンロード：
   - `windows-debug-build` (14日間保持)
   - `windows-release-build` (30日間保持)

## テスト

### 環境構築

```powershell
flutter --version              # Flutter 3.27.1 以降を確認
flutter config --enable-windows-desktop
flutter pub get
```

### 実行

```powershell
# デバッグモードで起動
flutter run -d windows

# または、ビルドして実行
flutter build windows --debug
.\build\windows\x64\runner\Debug\vagina.exe
```

### テスト項目

#### 基本機能
- [ ] アプリケーション起動
- [ ] UI 表示（日本語フォント含む）
- [ ] ウィンドウのリサイズ・最小化・最大化

#### マイク・音声
- [ ] マイク権限要求ダイアログ
- [ ] 音声入力（波形表示）
- [ ] 録音開始・停止
- [ ] AI 音声応答の再生

#### ネットワーク
- [ ] 設定画面
- [ ] API キー入力・保存
- [ ] Azure OpenAI Realtime API 接続
- [ ] WebSocket 接続安定性

#### その他
- [ ] 正常終了
- [ ] クラッシュ・フリーズなし
- [ ] メモリリーク・CPU 使用率

## 既知の問題

### 音声再生が動作しない

**症状**: flutter_sound パッケージが Windows で実装不完全

**影響**:
- ✅ Android/iOS/macOS/Linux: 音声再生サポート
- ❌ Windows: 音声再生不可
- ✅ 全プラットフォーム: 音声録音動作

**回避策**:
1. just_audio への移行（推奨）
2. WebRTC への移行（ノイズキャンセリング対応も含む）
3. ネイティブ実装（Method Channels + Windows Media Foundation）

詳細は [`WEBRTC_MIGRATION_GUIDE.md`](WEBRTC_MIGRATION_GUIDE.md) を参照。

## トラブルシューティング

### ビルドエラー

**「Visual Studio が見つかりません」**
```
Visual Studio build tools cannot be found
```
→ Visual Studio 2022 と C++ ワークロードをインストール

**DLL エラー**

実行時に DLL が見つからない場合：
1. すべての DLL が `.exe` と同じディレクトリにあるか確認
2. `data/` フォルダーも同じディレクトリにあるか確認

### マイクが動作しない

Windows の設定でマイク権限を確認：
- 設定 → プライバシー → マイク

### 音声が再生されない

1. Windows のサウンド設定を確認
2. 音量ミキサーでアプリケーションの音量を確認
3. 「既知の問題」を参照

### ビルドが遅い

- `flutter clean` でキャッシュをクリア
- 不要な依存関係を `pubspec.yaml` から削除
- SSD を使用

## 参考資料

- [Flutter Desktop Support](https://docs.flutter.dev/desktop)
- [Building Windows Apps](https://docs.flutter.dev/platform-integration/windows/building)
- [GitHub Actions - Windows Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners)
