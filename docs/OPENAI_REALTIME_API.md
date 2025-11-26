# Azure OpenAI Realtime API 仕様書

本ドキュメントは、VAGINA アプリで使用する Azure OpenAI Realtime API の仕様をまとめたものです。

## 概要

Azure OpenAI Realtime API は、WebSocket を使用した双方向リアルタイム音声通信 API です。音声入力をストリーミングで送信し、AI からの音声応答をリアルタイムで受信できます。

## 接続情報

### エンドポイント

**Azure OpenAI:**
```
wss://{resource-name}.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment={deployment-name}
```

例:
```
wss://my-resource.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-4o-realtime-preview
```

### 認証

WebSocket 接続時に `api-key` クエリパラメータで API キーを渡します：

```
wss://{resource}.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment={deployment}&api-key={YOUR_API_KEY}
```

> ⚠️ **セキュリティ注意**: API キーはデバイスの Secure Storage に安全に保存されます。

## 音声フォーマット

| 項目 | 値 |
|------|-----|
| フォーマット | PCM16 (Linear PCM, 16-bit signed integer) |
| サンプルレート | 24,000 Hz |
| チャンネル | モノラル (1ch) |
| エンコード | Base64 (JSON内で送信時) |

### 音声データ変換 (Flutter/Dart)

```dart
// Float32 → PCM16 変換
Uint8List float32ToPcm16(Float32List input) {
  final output = Int16List(input.length);
  for (var i = 0; i < input.length; i++) {
    final sample = (input[i] * 32767).clamp(-32768, 32767).toInt();
    output[i] = sample;
  }
  return output.buffer.asUint8List();
}

// PCM16 → Base64 エンコード
String pcm16ToBase64(Uint8List pcmData) {
  return base64Encode(pcmData);
}
```

## イベントタイプ

### クライアント → サーバー (送信イベント)

#### `session.update`
セッション設定を更新します。接続直後に送信することを推奨。

```json
{
  "type": "session.update",
  "session": {
    "modalities": ["text", "audio"],
    "instructions": "You are a helpful assistant.",
    "voice": "alloy",
    "input_audio_format": "pcm16",
    "output_audio_format": "pcm16",
    "input_audio_transcription": {
      "model": "whisper-1"
    },
    "turn_detection": {
      "type": "server_vad",
      "threshold": 0.5,
      "prefix_padding_ms": 300,
      "silence_duration_ms": 500
    }
  }
}
```

#### `input_audio_buffer.append`
音声データを追加します。

```json
{
  "type": "input_audio_buffer.append",
  "audio": "BASE64_ENCODED_PCM16_DATA"
}
```

#### `input_audio_buffer.commit`
現在のオーディオバッファをコミットします（VAD 無効時に使用）。

```json
{
  "type": "input_audio_buffer.commit"
}
```

#### `input_audio_buffer.clear`
オーディオバッファをクリアします。

```json
{
  "type": "input_audio_buffer.clear"
}
```

#### `response.create`
応答生成をリクエストします（VAD 無効時に使用）。

```json
{
  "type": "response.create",
  "response": {
    "modalities": ["audio", "text"]
  }
}
```

#### `response.cancel`
現在の応答をキャンセルします。

```json
{
  "type": "response.cancel"
}
```

### サーバー → クライアント (受信イベント)

#### `session.created`
セッションが作成されたことを通知。

#### `session.updated`
セッション設定が更新されたことを通知。

#### `input_audio_buffer.speech_started`
VAD が音声開始を検出。

#### `input_audio_buffer.speech_stopped`
VAD が音声終了を検出。

#### `response.audio.delta`
音声応答のチャンク（Base64 エンコード）。

```json
{
  "type": "response.audio.delta",
  "delta": "BASE64_ENCODED_PCM16_DATA"
}
```

#### `response.audio.done`
音声応答の送信完了。

#### `response.audio_transcript.delta`
音声応答のテキスト書き起こし（差分）。

```json
{
  "type": "response.audio_transcript.delta",
  "delta": "Hello"
}
```

#### `response.done`
応答の完了。

#### `error`
エラー発生。

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Error description"
  }
}
```

## Voice Activity Detection (VAD)

Server VAD を有効にすると、サーバー側で音声の開始・終了を自動検出します。

### VAD 設定パラメータ

| パラメータ | 説明 | 推奨値 |
|-----------|------|--------|
| `type` | VAD タイプ | `"server_vad"` |
| `threshold` | 音声検出閾値 (0.0-1.0) | `0.5` |
| `prefix_padding_ms` | 音声開始前のパディング | `300` |
| `silence_duration_ms` | 音声終了と判定する無音時間 | `500` |

## 利用可能な音声

| 音声名 | 説明 |
|--------|------|
| `alloy` | ニュートラル |
| `echo` | 男性的 |
| `shimmer` | 女性的 |

## 制限事項

1. **同時接続**: 1アカウントあたりの同時 WebSocket 接続数に制限あり
2. **セッション時間**: 長時間のセッションは自動切断される可能性あり
3. **レート制限**: API 呼び出しにはレート制限が適用される
4. **音声長**: 1回の応答で生成できる音声の長さに制限あり

## 実装パターン

### 基本的な接続フロー

```
1. WebSocket 接続確立
2. session.update 送信（設定の初期化）
3. 音声キャプチャ開始
4. input_audio_buffer.append でストリーミング送信
5. VAD が音声終了を検出 → 自動的に応答生成
6. response.audio.delta で音声を受信・再生
7. response.done で1ターン完了
8. 以降 3-7 を繰り返し
```

### 再接続戦略

接続が切断された場合の再接続には指数バックオフを推奨：

```dart
int retryAttempt = 0;
const maxRetries = 5;
const baseBackoffMs = 500;

int calculateBackoff(int attempt) {
  final exp = min(attempt, 6);
  final base = baseBackoffMs * pow(2, exp);
  final jitter = Random().nextInt(250);
  return base + jitter;
}
```

## 参考リンク

- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [Azure OpenAI Realtime Audio](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-quickstart)
- [ANL-enpit (Web版サンプル実装)](https://github.com/yuki-js/ANL-enpit)
