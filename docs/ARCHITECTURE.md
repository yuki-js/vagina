# アーキテクチャガイド

## 概要

VAGINA は、Flutter を使用したクロスプラットフォーム (Android/iOS) の音声 AI アシスタントアプリです。Azure OpenAI Realtime API を使用してリアルタイム音声会話を実現します。

## ディレクトリ構成

```
vagina/
├── lib/                        # メインアプリケーション
│   ├── main.dart              # エントリーポイント
│   ├── config/                # アプリ設定
│   │   └── app_config.dart    # 定数・設定値
│   ├── models/                # データモデル
│   │   └── assistant_config.dart
│   ├── services/              # ビジネスロジック・API
│   │   ├── secure_storage_service.dart
│   │   ├── audio_recorder_service.dart
│   │   ├── audio_player_service.dart
│   │   ├── websocket_service.dart
│   │   └── realtime_api_client.dart
│   ├── providers/             # Riverpod プロバイダー
│   │   └── providers.dart
│   ├── screens/               # 画面
│   │   ├── call_screen.dart
│   │   ├── settings_screen.dart
│   │   └── components/        # 画面コンポーネント
│   ├── widgets/               # 再利用可能ウィジェット
│   │   ├── call_button.dart
│   │   └── circular_icon_button.dart
│   └── theme/                 # テーマ定義
│       └── app_theme.dart
└── docs/                      # ドキュメント
```

### 設計方針

**シンプルな構造**: このアプリのスコープでは、複数のパッケージに分割するオーバーエンジニアリングを避け、`lib/` ディレクトリ内でサブディレクトリによる論理的な分離を行っています。

### 各ディレクトリの責務

#### `config/`
- アプリ設定の管理 (API バージョン、音声設定など)

#### `models/`
- データクラス定義 (AssistantConfig など)

#### `services/`
- セキュアストレージサービス (API キー保存)
- マイク入力のキャプチャ (`record` パッケージ)
- 音声再生 (`just_audio` パッケージ)
- WebSocket 接続管理
- Azure OpenAI Realtime API との通信

#### `providers/`
- Riverpod の全プロバイダー定義
- 依存性注入

#### `screens/`
- 通話メイン画面
- 設定画面
- 画面固有のコンポーネント

#### `widgets/`
- 複数画面で再利用可能な UI ウィジェット

#### `theme/`
- アプリのテーマ定義

## 状態管理

### 採用技術: Riverpod

状態管理には **Riverpod** を採用しています。

#### 選定理由
1. **コンパイル時の安全性**: Provider と比較してコンパイル時に依存関係のエラーを検出
2. **テスト容易性**: プロバイダーのオーバーライドが容易
3. **スコープ管理**: 自動的なリソース解放
4. **非同期対応**: FutureProvider, StreamProvider の充実

### プロバイダーの種類と使い分け

```dart
// 単純な状態
final isMutedProvider = StateProvider<bool>((ref) => false);

// サービスインスタンス (シングルトン)
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

// 非同期データ
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return await storage.getApiKey();
});

// 複雑な状態 (StateNotifier)
final assistantConfigProvider = StateNotifierProvider<AssistantConfigNotifier, AssistantConfig>((ref) {
  return AssistantConfigNotifier();
});
```

## 音声処理パイプライン

```
┌─────────────────┐
│   マイク入力     │
└────────┬────────┘
         │ Float32 (44.1kHz/48kHz)
         ▼
┌─────────────────┐
│  ダウンサンプリング │
│    24kHz 変換    │
└────────┬────────┘
         │ Float32 (24kHz)
         ▼
┌─────────────────┐
│  PCM16 変換      │
└────────┬────────┘
         │ Int16 (24kHz)
         ▼
┌─────────────────┐
│  Base64 エンコード │
└────────┬────────┘
         │ String
         ▼
┌─────────────────┐
│  WebSocket 送信  │
│ (input_audio_   │
│  buffer.append) │
└─────────────────┘
```

## セキュリティ設計

### API キーの管理

1. **入力**: 設定画面から手動入力
2. **保存**: `flutter_secure_storage` でプラットフォームの安全なストレージに保存
   - Android: EncryptedSharedPreferences
   - iOS: Keychain
3. **使用**: WebSocket 接続時にのみメモリに読み込み
4. **非公開**: `.gitignore` で `.env` ファイルを除外

### 注意事項

- API キーは GitHub にプッシュしない
- 本番環境では中間サーバーの使用を検討
- ユーザーに API キー管理の責任を周知

## コーディングスタイル

### Dart 命名規則

```dart
// クラス名: UpperCamelCase
class AudioRecorderService {}

// 変数名・関数名: lowerCamelCase
void startRecording() {}
final isRecording = false;

// 定数: lowerCamelCase
const defaultMicGain = 0.8;

// プライベート: アンダースコアプレフィックス
bool _isConnected = false;
```

### ファイル構成

```dart
// 1. インポート (dart:, package:, relative: の順)
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

// 2. 定数

// 3. クラス定義
```

### Widget 構造

```dart
class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: リビルドが必要な状態
    final isMuted = ref.watch(isMutedProvider);
    
    // ref.read: 1回だけ読み取る (コールバック内で使用)
    onPressed: () {
      ref.read(isMutedProvider.notifier).state = true;
    }
  }
}
```

## テスト戦略

### 単体テスト
- サービスクラスのロジック
- 状態管理のプロバイダー

### ウィジェットテスト
- 個別 UI コンポーネント
- 画面遷移

### 統合テスト
- エンドツーエンドの通話フロー
- API 接続 (モック使用)

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| `flutter_riverpod` | 状態管理 |
| `record` | マイク入力 |
| `just_audio` | 音声再生 |
| `web_socket_channel` | WebSocket 通信 |
| `http` | HTTP リクエスト |
| `flutter_dotenv` | 環境変数 |
| `permission_handler` | 権限管理 |
| `flutter_secure_storage` | セキュアストレージ |
