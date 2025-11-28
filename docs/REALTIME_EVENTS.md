# OpenAI Realtime API Events 完全リファレンス

本ドキュメントは、VAGINA アプリで処理する OpenAI Realtime API の全 WebSocket イベントを解説します。

## 概要

OpenAI Realtime API は WebSocket を使用した双方向リアルタイム通信 API です。クライアントとサーバー間で JSON 形式のイベントをやり取りします。

- **クライアントイベント**: 12 種類（クライアント → サーバー）
- **サーバーイベント**: 36 種類（サーバー → クライアント）

## クライアントイベント（12 種類）

クライアントからサーバーに送信するイベントです。

### 1. `session.update`

セッション設定を更新します。

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
    },
    "tools": []
  }
}
```

| フィールド | 説明 |
|-----------|------|
| `modalities` | 使用するモダリティ（`text`, `audio`） |
| `instructions` | システムプロンプト |
| `voice` | 音声タイプ（`alloy`, `echo`, `shimmer` など） |
| `input_audio_format` | 入力音声フォーマット（`pcm16`） |
| `output_audio_format` | 出力音声フォーマット（`pcm16`） |
| `input_audio_transcription` | 入力音声の書き起こし設定 |
| `turn_detection` | VAD（Voice Activity Detection）設定 |
| `tools` | 使用可能なツール（関数）のリスト |

### 2. `input_audio_buffer.append`

音声データをバッファに追加します。

```json
{
  "type": "input_audio_buffer.append",
  "audio": "BASE64_ENCODED_PCM16_DATA"
}
```

### 3. `input_audio_buffer.commit`

音声バッファをコミットして処理をトリガーします（VAD 無効時に使用）。

```json
{
  "type": "input_audio_buffer.commit"
}
```

### 4. `input_audio_buffer.clear`

音声バッファをクリアします。

```json
{
  "type": "input_audio_buffer.clear"
}
```

### 5. `output_audio_buffer.clear`

出力音声バッファをクリアします（WebRTC のみ）。

```json
{
  "type": "output_audio_buffer.clear"
}
```

### 6. `conversation.item.create`

会話にアイテムを追加します（メッセージ、関数呼び出し結果など）。

```json
{
  "type": "conversation.item.create",
  "previous_item_id": null,
  "item": {
    "type": "message",
    "role": "user",
    "content": [
      {
        "type": "input_text",
        "text": "Hello!"
      }
    ]
  }
}
```

### 7. `conversation.item.truncate`

会話アイテムの音声を切り詰めます。

```json
{
  "type": "conversation.item.truncate",
  "item_id": "msg_001",
  "content_index": 0,
  "audio_end_ms": 1500
}
```

### 8. `conversation.item.delete`

会話アイテムを削除します。

```json
{
  "type": "conversation.item.delete",
  "item_id": "msg_001"
}
```

### 9. `conversation.item.retrieve`

会話アイテムを取得します。

```json
{
  "type": "conversation.item.retrieve",
  "item_id": "msg_001"
}
```

### 10. `response.create`

AI からの応答生成をリクエストします。

```json
{
  "type": "response.create",
  "response": {
    "modalities": ["audio", "text"]
  }
}
```

### 11. `response.cancel`

現在の応答生成をキャンセルします。

```json
{
  "type": "response.cancel"
}
```

### 12. `transcription_session.update`

書き起こしセッションの設定を更新します。

```json
{
  "type": "transcription_session.update",
  "session": {
    "input_audio_transcription": {
      "model": "gpt-4o-transcribe"
    }
  }
}
```

---

## サーバーイベント（36 種類）

サーバーからクライアントに送信されるイベントです。

### セッションイベント

#### 1. `session.created`

セッションが作成されたときに送信されます（接続後の最初のイベント）。

```json
{
  "event_id": "event_1234",
  "type": "session.created",
  "session": {
    "id": "sess_001",
    "object": "realtime.session",
    "model": "gpt-4o-realtime-preview",
    "modalities": ["text", "audio"],
    "voice": "sage",
    "temperature": 0.8
  }
}
```

#### 2. `session.updated`

セッション設定が更新されたときに送信されます。

```json
{
  "event_id": "event_5678",
  "type": "session.updated",
  "session": {
    "id": "sess_001",
    "modalities": ["text"],
    "voice": "sage"
  }
}
```

#### 3. `transcription_session.updated`

書き起こしセッションが更新されたときに送信されます。

```json
{
  "event_id": "event_5678",
  "type": "transcription_session.updated",
  "session": {
    "id": "sess_001",
    "input_audio_transcription": {
      "model": "gpt-4o-transcribe"
    }
  }
}
```

---

### 会話イベント

#### 4. `conversation.created`

会話が作成されたときに送信されます（セッション作成直後）。

```json
{
  "event_id": "event_9101",
  "type": "conversation.created",
  "conversation": {
    "id": "conv_001",
    "object": "realtime.conversation"
  }
}
```

#### 5. `conversation.item.created`

会話アイテムが作成されたときに送信されます。

```json
{
  "event_id": "event_1920",
  "type": "conversation.item.created",
  "previous_item_id": "msg_002",
  "item": {
    "id": "msg_003",
    "object": "realtime.item",
    "type": "message",
    "status": "completed",
    "role": "user",
    "content": []
  }
}
```

#### 6. `conversation.item.deleted`

会話アイテムが削除されたときに送信されます。

```json
{
  "event_id": "event_2728",
  "type": "conversation.item.deleted",
  "item_id": "msg_005"
}
```

#### 7. `conversation.item.truncated`

会話アイテムが切り詰められたときに送信されます。

```json
{
  "event_id": "event_2526",
  "type": "conversation.item.truncated",
  "item_id": "msg_004",
  "content_index": 0,
  "audio_end_ms": 1500
}
```

#### 8. `conversation.item.retrieved`

会話アイテムが取得されたときに送信されます。

```json
{
  "event_id": "event_1920",
  "type": "conversation.item.retrieved",
  "item": {
    "id": "msg_003",
    "object": "realtime.item",
    "type": "message",
    "content": [...]
  }
}
```

---

### 入力音声書き起こしイベント

#### 9. `conversation.item.input_audio_transcription.completed`

ユーザーの音声書き起こしが完了したときに送信されます。

```json
{
  "event_id": "event_2122",
  "type": "conversation.item.input_audio_transcription.completed",
  "item_id": "msg_003",
  "content_index": 0,
  "transcript": "Hello, how are you?"
}
```

#### 10. `conversation.item.input_audio_transcription.delta`

ユーザーの音声書き起こしの差分が送信されます（ストリーミング）。

```json
{
  "type": "conversation.item.input_audio_transcription.delta",
  "event_id": "event_001",
  "item_id": "item_001",
  "content_index": 0,
  "delta": "Hello"
}
```

#### 11. `conversation.item.input_audio_transcription.failed`

音声書き起こしが失敗したときに送信されます。

```json
{
  "event_id": "event_2324",
  "type": "conversation.item.input_audio_transcription.failed",
  "item_id": "msg_003",
  "content_index": 0,
  "error": {
    "type": "transcription_error",
    "code": "audio_unintelligible",
    "message": "The audio could not be transcribed."
  }
}
```

---

### 入力音声バッファイベント

#### 12. `input_audio_buffer.committed`

音声バッファがコミットされたときに送信されます。

```json
{
  "event_id": "event_1121",
  "type": "input_audio_buffer.committed",
  "previous_item_id": "msg_001",
  "item_id": "msg_002"
}
```

#### 13. `input_audio_buffer.cleared`

音声バッファがクリアされたときに送信されます。

```json
{
  "event_id": "event_1314",
  "type": "input_audio_buffer.cleared"
}
```

#### 14. `input_audio_buffer.speech_started`

VAD が音声開始を検出したときに送信されます。

```json
{
  "event_id": "event_1516",
  "type": "input_audio_buffer.speech_started",
  "audio_start_ms": 1000,
  "item_id": "msg_003"
}
```

**重要**: このイベントを受信したら、現在再生中の AI 音声を停止（割り込み）する必要があります。

#### 15. `input_audio_buffer.speech_stopped`

VAD が音声終了を検出したときに送信されます。

```json
{
  "event_id": "event_1718",
  "type": "input_audio_buffer.speech_stopped",
  "audio_end_ms": 2000,
  "item_id": "msg_003"
}
```

---

### 出力音声バッファイベント（WebRTC のみ）

これらのイベントは WebRTC 接続でのみ送信され、WebSocket 接続では通常使用されません。

#### 16. `output_audio_buffer.started`

サーバーが音声ストリーミングを開始したときに送信されます。

```json
{
  "event_id": "event_abc123",
  "type": "output_audio_buffer.started",
  "response_id": "resp_abc123"
}
```

#### 17. `output_audio_buffer.stopped`

出力音声バッファが空になったときに送信されます。

```json
{
  "event_id": "event_abc123",
  "type": "output_audio_buffer.stopped",
  "response_id": "resp_abc123"
}
```

#### 18. `output_audio_buffer.cleared`

出力音声バッファがクリアされたときに送信されます。

```json
{
  "event_id": "event_abc123",
  "type": "output_audio_buffer.cleared",
  "response_id": "resp_abc123"
}
```

---

### 応答イベント

#### 19. `response.created`

応答生成が開始されたときに送信されます。

```json
{
  "event_id": "event_2930",
  "type": "response.created",
  "response": {
    "id": "resp_001",
    "object": "realtime.response",
    "status": "in_progress",
    "output": []
  }
}
```

#### 20. `response.done`

応答生成が完了したときに送信されます。

```json
{
  "event_id": "event_3132",
  "type": "response.done",
  "response": {
    "id": "resp_001",
    "object": "realtime.response",
    "status": "completed",
    "output": [...],
    "usage": {
      "total_tokens": 275,
      "input_tokens": 127,
      "output_tokens": 148
    }
  }
}
```

---

### 応答出力アイテムイベント

#### 21. `response.output_item.added`

応答生成中に新しいアイテムが追加されたときに送信されます。

```json
{
  "event_id": "event_3334",
  "type": "response.output_item.added",
  "response_id": "resp_001",
  "output_index": 0,
  "item": {
    "id": "msg_007",
    "object": "realtime.item",
    "type": "message",
    "status": "in_progress",
    "role": "assistant",
    "content": []
  }
}
```

#### 22. `response.output_item.done`

アイテムのストリーミングが完了したときに送信されます。

```json
{
  "event_id": "event_3536",
  "type": "response.output_item.done",
  "response_id": "resp_001",
  "output_index": 0,
  "item": {
    "id": "msg_007",
    "status": "completed",
    "content": [...]
  }
}
```

---

### 応答コンテンツパートイベント

#### 23. `response.content_part.added`

新しいコンテンツパートが追加されたときに送信されます。

```json
{
  "event_id": "event_3738",
  "type": "response.content_part.added",
  "response_id": "resp_001",
  "item_id": "msg_007",
  "output_index": 0,
  "content_index": 0,
  "part": {
    "type": "text",
    "text": ""
  }
}
```

#### 24. `response.content_part.done`

コンテンツパートのストリーミングが完了したときに送信されます。

```json
{
  "event_id": "event_3940",
  "type": "response.content_part.done",
  "response_id": "resp_001",
  "item_id": "msg_007",
  "output_index": 0,
  "content_index": 0,
  "part": {
    "type": "text",
    "text": "Sure, I can help with that."
  }
}
```

---

### 応答テキストイベント

#### 25. `response.text.delta`

テキスト応答の差分が送信されます。

```json
{
  "event_id": "event_4142",
  "type": "response.text.delta",
  "response_id": "resp_001",
  "item_id": "msg_007",
  "output_index": 0,
  "content_index": 0,
  "delta": "Sure, I can h"
}
```

#### 26. `response.text.done`

テキスト応答が完了したときに送信されます。

```json
{
  "event_id": "event_4344",
  "type": "response.text.done",
  "response_id": "resp_001",
  "item_id": "msg_007",
  "output_index": 0,
  "content_index": 0,
  "text": "Sure, I can help with that."
}
```

---

### 応答音声書き起こしイベント

#### 27. `response.audio_transcript.delta`

AI 音声の書き起こし差分が送信されます。

```json
{
  "event_id": "event_4546",
  "type": "response.audio_transcript.delta",
  "response_id": "resp_001",
  "item_id": "msg_008",
  "output_index": 0,
  "content_index": 0,
  "delta": "Hello, how can I a"
}
```

#### 28. `response.audio_transcript.done`

AI 音声の書き起こしが完了したときに送信されます。

```json
{
  "event_id": "event_4748",
  "type": "response.audio_transcript.done",
  "response_id": "resp_001",
  "item_id": "msg_008",
  "output_index": 0,
  "content_index": 0,
  "transcript": "Hello, how can I assist you today?"
}
```

---

### 応答音声イベント

#### 29. `response.audio.delta`

音声データの差分が送信されます（Base64 エンコード）。

```json
{
  "event_id": "event_4950",
  "type": "response.audio.delta",
  "response_id": "resp_001",
  "item_id": "msg_008",
  "output_index": 0,
  "content_index": 0,
  "delta": "Base64EncodedAudioDelta"
}
```

#### 30. `response.audio.done`

音声ストリーミングが完了したときに送信されます。

```json
{
  "event_id": "event_5152",
  "type": "response.audio.done",
  "response_id": "resp_001",
  "item_id": "msg_008",
  "output_index": 0,
  "content_index": 0
}
```

---

### 応答関数呼び出しイベント

#### 31. `response.function_call_arguments.delta`

関数呼び出し引数の差分が送信されます。

```json
{
  "event_id": "event_5354",
  "type": "response.function_call_arguments.delta",
  "response_id": "resp_002",
  "item_id": "fc_001",
  "output_index": 0,
  "call_id": "call_001",
  "delta": "{\"location\": \"San\""
}
```

#### 32. `response.function_call_arguments.done`

関数呼び出し引数が完了したときに送信されます。

```json
{
  "event_id": "event_5556",
  "type": "response.function_call_arguments.done",
  "response_id": "resp_002",
  "item_id": "fc_001",
  "output_index": 0,
  "call_id": "call_001",
  "arguments": "{\"location\": \"San Francisco\"}"
}
```

---

### レート制限イベント

#### 33. `rate_limits.updated`

応答開始時にレート制限情報が送信されます。

```json
{
  "event_id": "event_5758",
  "type": "rate_limits.updated",
  "rate_limits": [
    {
      "name": "requests",
      "limit": 1000,
      "remaining": 999,
      "reset_seconds": 60
    },
    {
      "name": "tokens",
      "limit": 50000,
      "remaining": 49950,
      "reset_seconds": 60
    }
  ]
}
```

---

### エラーイベント

#### 34-36. `error`

エラーが発生したときに送信されます。

```json
{
  "event_id": "event_890",
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "code": "invalid_event",
    "message": "The 'type' field is missing.",
    "param": null,
    "event_id": "event_567"
  }
}
```

| エラータイプ | 説明 |
|-------------|------|
| `invalid_request_error` | リクエストの形式が不正 |
| `server_error` | サーバー側のエラー |
| `rate_limit_error` | レート制限超過 |

---

## イベントの流れ

### 基本的な会話フロー

```
1. [接続確立]
   ← session.created
   ← conversation.created
   → session.update

2. [設定更新]
   ← session.updated

3. [ユーザー発話]
   → input_audio_buffer.append (連続)
   ← input_audio_buffer.speech_started (VAD)
   ← input_audio_buffer.speech_stopped (VAD)
   ← input_audio_buffer.committed
   ← conversation.item.created
   ← conversation.item.input_audio_transcription.completed

4. [AI 応答]
   ← response.created
   ← rate_limits.updated
   ← response.output_item.added
   ← response.content_part.added
   ← response.audio.delta (連続)
   ← response.audio_transcript.delta (連続)
   ← response.audio.done
   ← response.audio_transcript.done
   ← response.content_part.done
   ← response.output_item.done
   ← response.done
   ← conversation.item.created
```

### 割り込み（Interrupt）フロー

```
1. [AI 応答中]
   ← response.audio.delta (連続)

2. [ユーザーが話し始める]
   ← input_audio_buffer.speech_started
   [クライアント側で音声再生を停止]
   → response.cancel (オプション)

3. [新しいユーザー入力の処理]
   ← input_audio_buffer.speech_stopped
   ← input_audio_buffer.committed
   ...
```

### 関数呼び出しフロー

```
1. [AI が関数呼び出しを決定]
   ← response.output_item.added (type: function_call)
   ← response.function_call_arguments.delta (連続)
   ← response.function_call_arguments.done

2. [クライアント側で関数を実行]
   → conversation.item.create (function_call_output)
   → response.create

3. [AI が関数結果を処理して応答]
   ← response.created
   ...
```

---

## 実装上の注意点

### 1. 割り込み処理

`input_audio_buffer.speech_started` を受信したら、即座に現在再生中の音声を停止してください。ユーザーが話し始めた際の自然な割り込みを実現するために重要です。

### 2. ストリーミング処理

`delta` イベントは非常に頻繁に送信されるため、効率的なバッファリングと処理が必要です。特に音声データ（`response.audio.delta`）は大量のデータを含みます。

### 3. エラーハンドリング

ほとんどのエラーは回復可能です。セッションは維持されるため、エラーをログに記録しつつ処理を継続できます。

### 4. WebRTC vs WebSocket

`output_audio_buffer.*` イベントは WebRTC 接続でのみ使用されます。WebSocket 接続では、音声データは `response.audio.delta` で送信されます。

---

## 参考リンク

- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [OpenAI API Reference - Realtime Events](https://platform.openai.com/docs/api-reference/realtime)
- [Azure OpenAI Realtime Audio](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-quickstart)
