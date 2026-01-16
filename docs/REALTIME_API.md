# Azure OpenAI Realtime API リファレンス

VAGINA アプリで使用する Azure OpenAI Realtime API の仕様とイベントリファレンスです。

## 接続

### エンドポイント

```
wss://{resource-name}.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment={deployment-name}&api-key={YOUR_API_KEY}
```

### 音声フォーマット

| 項目 | 値 |
|------|-----|
| フォーマット | PCM16 (16-bit signed integer) |
| サンプルレート | 24,000 Hz |
| チャンネル | モノラル (1ch) |
| エンコード | Base64 (JSON内) |

### 音声データ変換

```dart
// Float32 → PCM16
Uint8List float32ToPcm16(Float32List input) {
  final output = Int16List(input.length);
  for (var i = 0; i < input.length; i++) {
    final sample = (input[i] * 32767).clamp(-32768, 32767).toInt();
    output[i] = sample;
  }
  return output.buffer.asUint8List();
}

// PCM16 → Base64
String pcm16ToBase64(Uint8List pcmData) => base64Encode(pcmData);
```

## 主要イベント

### クライアント → サーバー

#### セッション設定

```json
{
  "type": "session.update",
  "session": {
    "modalities": ["text", "audio"],
    "instructions": "You are a helpful assistant.",
    "voice": "alloy",
    "input_audio_format": "pcm16",
    "output_audio_format": "pcm16",
    "turn_detection": {
      "type": "server_vad",
      "threshold": 0.5,
      "prefix_padding_ms": 300,
      "silence_duration_ms": 500
    }
  }
}
```

#### 音声データ送信

```json
{
  "type": "input_audio_buffer.append",
  "audio": "BASE64_ENCODED_PCM16_DATA"
}
```

#### 応答キャンセル

```json
{
  "type": "response.cancel"
}
```

### サーバー → クライアント

#### セッション確立

- `session.created` - セッション作成完了
- `session.updated` - 設定更新完了

#### 音声認識（VAD）

- `input_audio_buffer.speech_started` - **音声開始検出（重要：AI音声を停止）**
- `input_audio_buffer.speech_stopped` - 音声終了検出

#### AI応答

- `response.created` - 応答生成開始
- `response.audio.delta` - **音声データチャンク（再生）**
- `response.audio_transcript.delta` - テキスト書き起こし
- `response.done` - 応答完了

#### エラー

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error|server_error|rate_limit_error",
    "message": "Error description"
  }
}
```

## VAD（音声認識）設定

| パラメータ | 説明 | 推奨値 |
|-----------|------|--------|
| `type` | VADタイプ | `"server_vad"` |
| `threshold` | 音声検出閾値 (0.0-1.0) | `0.5` |
| `prefix_padding_ms` | 音声開始前パディング | `300` |
| `silence_duration_ms` | 無音判定時間 | `500` |

## 利用可能な音声

| 音声名 | 説明 |
|--------|------|
| `alloy` | ニュートラル |
| `echo` | 男性的 |
| `shimmer` | 女性的 |

## 実装パターン

### 基本フロー

```
1. WebSocket 接続
2. session.update 送信
3. 音声キャプチャ開始
4. input_audio_buffer.append で送信
5. VAD が音声終了検出 → 自動応答生成
6. response.audio.delta で音声受信・再生
7. response.done で完了
8. 3-7 を繰り返し
```

### 割り込み処理

```
[AI 応答中]
  ← response.audio.delta

[ユーザーが話し始める]
  ← input_audio_buffer.speech_started
  → クライアント側で音声再生を停止（重要）
  → response.cancel（オプション）
```

### 再接続戦略

指数バックオフを推奨：

```dart
int calculateBackoff(int attempt) {
  final exp = min(attempt, 6);
  final base = 500 * pow(2, exp);  // 500ms, 1s, 2s, 4s, 8s, 16s, 32s
  final jitter = Random().nextInt(250);
  return base + jitter;
}
```

## 全イベント一覧

### クライアントイベント（12種類）

1. `session.update` - セッション設定更新
2. `input_audio_buffer.append` - 音声データ追加
3. `input_audio_buffer.commit` - バッファコミット
4. `input_audio_buffer.clear` - バッファクリア
5. `conversation.item.create` - 会話アイテム追加
6. `conversation.item.truncate` - 音声切り詰め
7. `conversation.item.delete` - アイテム削除
8. `conversation.item.retrieve` - アイテム取得
9. `response.create` - 応答生成要求
10. `response.cancel` - 応答キャンセル
11. `transcription_session.update` - 書き起こし設定更新
12. `output_audio_buffer.clear` - 出力バッファクリア（WebRTC）

### サーバーイベント（36種類）

#### セッション (3)
- `session.created`, `session.updated`, `transcription_session.updated`

#### 会話 (5)
- `conversation.created`, `conversation.item.created`, `conversation.item.deleted`, `conversation.item.truncated`, `conversation.item.retrieved`

#### 入力音声書き起こし (3)
- `conversation.item.input_audio_transcription.completed`, `.delta`, `.failed`

#### 入力音声バッファ (3)
- `input_audio_buffer.committed`, `.cleared`, `.speech_started`, `.speech_stopped`

#### 出力音声バッファ (3, WebRTC専用)
- `output_audio_buffer.started`, `.stopped`, `.cleared`

#### 応答 (2)
- `response.created`, `response.done`

#### 応答出力アイテム (2)
- `response.output_item.added`, `.done`

#### 応答コンテンツパート (2)
- `response.content_part.added`, `.done`

#### 応答テキスト (2)
- `response.text.delta`, `.done`

#### 応答音声書き起こし (2)
- `response.audio_transcript.delta`, `.done`

#### 応答音声 (2)
- `response.audio.delta`, `.done`

#### 応答関数呼び出し (2)
- `response.function_call_arguments.delta`, `.done`

#### その他 (2)
- `rate_limits.updated`, `error`

詳細は[公式ドキュメント](https://platform.openai.com/docs/guides/realtime)を参照。

## 制限事項

1. **同時接続**: アカウントごとに制限あり
2. **セッション時間**: 長時間は自動切断
3. **レート制限**: API呼び出しに制限
4. **音声長**: 1応答あたりの制限あり

## 参考リンク

- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [Azure OpenAI Realtime Audio](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-quickstart)
- [ANL-enpit (Web版サンプル)](https://github.com/yuki-js/ANL-enpit)
