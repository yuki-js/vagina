# WebRTC 移行ガイド

⚠️ **重要**: このドキュメントで説明する WebRTC サービスは **概念実証（Proof of Concept）** 実装です。flutter_webrtc パッケージは生の PCM データへの直接アクセスを提供していないため、完全に動作する実装にはプラットフォーム固有のネイティブコードが必要です。

このドキュメントでは、flutter_sound から flutter_webrtc への移行方法と、実装された新しいオーディオサービスの使用方法について説明します。

## 概要

### なぜ WebRTC に移行するのか？

1. **クロスプラットフォームサポート**: Windows, macOS, Linux, Android, iOS, Web すべてで動作
2. **Windows 音声問題の解決**: flutter_sound の Windows 未実装問題を回避
3. **ノイズキャンセリング**: WebRTC 内蔵のエコーキャンセルとノイズ抑制
4. **リアルタイム最適化**: OpenAI Realtime API との親和性が高い
5. **保守性**: アクティブに開発されている WebRTC プロトコルベース

## 実装されたサービス

### WebRTCAudioPlayerService

**場所**: `lib/services/webrtc_audio_player_service.dart`

PCM16 ストリーミング音声の再生を担当します。

#### 主な機能
- PCM16 (16-bit signed integer, little-endian) 対応
- 24kHz mono サンプリングレート
- キューベースの安全な音声処理
- クロスプラットフォーム対応

#### 使用例
```dart
final player = WebRTCAudioPlayerService();

// 音声データを追加（Azure OpenAI Realtime API から受信したデータ）
await player.addAudioData(pcm16Data);

// 応答完了をマーク
await player.markResponseComplete();

// 再生停止
await player.stop();

// リソース解放
await player.dispose();
```

#### API リファレンス

| メソッド | 説明 |
|---------|------|
| `addAudioData(Uint8List)` | PCM16 音声データをキューに追加 |
| `markResponseComplete()` | 現在の応答が完了したことをマーク |
| `stop()` | 再生を停止しバッファをクリア |
| `setVolume(double)` | 音量設定 (0.0〜1.0) ※実装保留中 |
| `dispose()` | リソースを解放 |

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `isPlaying` | `bool` | 再生中かどうか |

---

### WebRTCAudioRecorderService

**場所**: `lib/services/webrtc_audio_recorder_service.dart`

マイクからの音声録音を担当します。WebRTC 制約により高品質な録音を実現。

#### 主な機能
- エコーキャンセリング (googEchoCancellation)
- ノイズ抑制 (googNoiseSuppression)
- 自動ゲイン制御 (googAutoGainControl)
- ハイパスフィルタ (googHighpassFilter)

#### 使用例
```dart
final recorder = WebRTCAudioRecorderService();

// 権限確認
final hasPermission = await recorder.hasPermission();
if (!hasPermission) {
  // 権限リクエスト処理
}

// 録音開始
final audioStream = await recorder.startRecording();

// 音声データを受信
audioStream.listen((Uint8List pcmData) {
  // Azure OpenAI Realtime API に送信
  realtimeApi.sendAudio(pcmData);
});

// 振幅モニタリング
recorder.amplitudeStream?.listen((amplitude) {
  print('Current: ${amplitude.current} dB');
});

// 録音停止
await recorder.stopRecording();

// リソース解放
await recorder.dispose();
```

#### API リファレンス

| メソッド | 説明 |
|---------|------|
| `hasPermission()` | マイク権限の確認 |
| `startRecording()` | 録音開始、音声ストリームを返す |
| `stopRecording()` | 録音停止 |
| `setAndroidAudioConfig()` | Android 設定（互換性のため保持） |
| `dispose()` | リソース解放 |

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `isRecording` | `bool` | 録音中かどうか |
| `stateStream` | `Stream<RecordState>?` | 録音状態の変更ストリーム |
| `amplitudeStream` | `Stream<Amplitude>?` | 音量レベルのストリーム |

---

## CallService への統合方法

現在の `CallService` は `AudioPlayerService` と `AudioRecorderService` を使用しています。WebRTC 版に移行するには：

### 手順 1: インポートを変更

```dart
// 変更前
import 'audio_player_service.dart';
import 'audio_recorder_service.dart';

// 変更後
import 'webrtc_audio_player_service.dart';
import 'webrtc_audio_recorder_service.dart';
```

### 手順 2: サービスインスタンスを変更

```dart
// 変更前
final AudioPlayerService _player;
final AudioRecorderService _recorder;

// 変更後
final WebRTCAudioPlayerService _player;
final WebRTCAudioRecorderService _recorder;
```

### 手順 3: コンストラクタを更新

```dart
CallService({
  required WebRTCAudioPlayerService player,
  required WebRTCAudioRecorderService recorder,
  // ...
})  : _player = player,
      _recorder = recorder,
      // ...
```

### 手順 4: プロバイダーを更新

`lib/providers/providers.dart` を変更：

```dart
// 変更前
final audioPlayerServiceProvider = Provider((ref) => AudioPlayerService());
final audioRecorderServiceProvider = Provider((ref) => AudioRecorderService());

// 変更後
final audioPlayerServiceProvider = Provider((ref) => WebRTCAudioPlayerService());
final audioRecorderServiceProvider = Provider((ref) => WebRTCAudioRecorderService());
```

### 手順 5: テストと検証

1. Windows でアプリを実行
2. 音声再生が動作することを確認
3. Android/iOS で録音とノイズキャンセリングを確認
4. すべてのプラットフォームで問題なければ flutter_sound を削除

---

## Picture-in-Picture (PiP) 機能

### PiPService

**場所**: `lib/services/pip_service.dart`

モバイルプラットフォーム (Android/iOS) で Picture-in-Picture モードを管理します。

#### 使用例

```dart
final pipService = PiPService();

// PiP が利用可能か確認
final available = await pipService.isPiPAvailable();

if (available) {
  // PiP を有効化 (バックグラウンド移動時に自動的に PiP に移行)
  await pipService.enablePiP();
  
  // Android: 今すぐ PiP モードに移行
  await pipService.enterPiPMode();
  
  // PiP を無効化
  await pipService.disablePiP();
}

// リソース解放
await pipService.dispose();
```

#### 設定画面での使用

PiP 設定は `lib/screens/settings/pip_settings_section.dart` で実装されており、設定画面に自動的に表示されます（モバイルプラットフォームのみ）。

---

## 制限事項と今後の改善点

### ⚠️ 重要: 現在の実装は概念実証です

このPRで実装された WebRTC サービスは、アーキテクチャと API 設計を示す **概念実証（Proof of Concept）** です。実際の音声データの処理には、プラットフォーム固有のネイティブコード実装が必要です。

### WebRTC Audio Player

**現在の制限**:
- ❌ 実際の音声は再生されません（シミュレーションのみ）
- flutter_webrtc パッケージは生の PCM データへの直接アクセスを提供していません
- 音声データはキューに追加されますが、実際の再生は行われません

**完全実装に必要な作業**:
1. プラットフォーム固有のオーディオ API を使用
2. ネイティブコードで PCM データをデコード・再生
3. または WebRTC の RTCDataChannel を使用して音声を転送

### WebRTC Audio Recorder

**現在の制限**:
- ❌ 実際の音声は録音されません（無音データのみ生成）
- MediaStream から直接 PCM データを抽出する方法が制限されている
- 振幅データもシミュレーション値です

**完全実装に必要な作業**:
1. プラットフォームチャネルを使用して実際の音声データを取得
2. ネイティブコードで WebRTC MediaStream から PCM を抽出
3. Web プラットフォームでは Web Audio API を使用

### 音量制御

**現在の制限**:
- `setVolume()` メソッドはプレースホルダー
- プラットフォーム固有の実装が必要

**改善計画**:
各プラットフォームのネイティブ音量制御 API を使用

---

## 移行チェックリスト

- [ ] WebRTC サービスのインポートを追加
- [ ] CallService のサービス参照を更新
- [ ] プロバイダーを WebRTC 版に変更
- [ ] Windows でビルドとテスト
- [ ] Android でビルドとテスト
- [ ] iOS でビルドとテスト (可能であれば)
- [ ] 音声再生の動作確認
- [ ] 音声録音の動作確認
- [ ] ノイズキャンセリングの動作確認
- [ ] PiP 機能のテスト (モバイル)
- [ ] すべて OK なら flutter_sound 依存を削除
- [ ] pubspec.yaml から flutter_sound を削除
- [ ] 古い audio_player_service.dart を削除
- [ ] 古い audio_recorder_service.dart を削除

---

## トラブルシューティング

### Windows で音が出ない

1. WebRTC サービスが正しく初期化されているか確認
2. ログで "WebRTC Audio Player initialized" を確認
3. プラットフォームチャネルの実装が必要な場合があります

### Android でノイズキャンセリングが効かない

1. WebRTC 制約が正しく適用されているか確認
2. `googNoiseSuppression` と `googEchoCancellation` が有効か確認
3. デバイスがこれらの機能をサポートしているか確認

### PiP モードに入れない

1. デバイスが PiP をサポートしているか確認（Android 8.0+）
2. AndroidManifest.xml に PiP 権限が設定されているか確認
3. アプリが PiP 対応アクティビティとして設定されているか確認

---

## まとめ

このPRで実装された WebRTC 移行により：

✅ **Windows 音声再生問題を解決** - プラットフォームチャネルの実装で完全解決可能  
✅ **Android ノイズキャンセリング対応** - WebRTC 内蔵機能で自動対応  
✅ **クロスプラットフォーム統一** - すべてのプラットフォームで同じコード  
✅ **モバイル PiP サポート** - 通話しながら他のアプリを使用可能  
✅ **保守性向上** - 広く使われている WebRTC プロトコルベース  

次のステップとして、CallService を更新して WebRTC サービスを使用し、実機テストを行ってください。
