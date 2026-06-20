# VHRP/1 Wire Protocol

## 目的

VHRP/1 は [`RealtimeAdapter`](../../lib/feat/call/services/realtime/realtime_adapter.dart) を満たすための hosted proprietary client-server protocol である。

設計原則:

1. on-wire では JSON を使わない
2. audio / image は binary のまま運ぶ
3. thread 表現は vendor event ではなく `RealtimeThread` patch に落とす
4. Quarkus で decode / validate / route しやすい単純な envelope にする

## Transport

- scheme: `wss`
- endpoint: `/api/hosted-realtime/v1/connect`
- WebSocket subprotocol: `vhrp.cbor.v1`
- transport security: TLS 必須
- compression: 無効を推奨
- client reconnect/resume: retention window 内で対応

## Session Bootstrap

1. client は WebSocket を開く
2. 最初の application message は必ず `session.open` でなければならない
3. `session.open.body.token` に JWT を載せて認証する
4. 新規 session なら server は `session.ready`、resume 成功なら `session.resumed` を返す
5. 以降は双方向 CBOR message を交換する

resume を使う場合でも entrypoint は同じ `session.open` であり、`body.resume` の有無だけが違う。

補足:

- VHRP/1 が定義する application-level authentication credential は `session.open.body.token` の JWT だけである
- WebSocket handshake や browser 内部の preflight/cookie/token は protocol 外であり、本仕様は関知しない
- JWT refresh と WebSocket connection lifetime は本質的に独立であり、v1 では連動規則を定義しない。例えば、JWT が期限切れになってもWebSocketを切断するかどうかを規定しないし、WebSocketが維持中にJWTを更新する方法も規定しない

## Encoding

### 基本ルール

- すべての application message は **1 WebSocket message = 1 CBOR map**
- text frame は使わない
- UTF-8 text は CBOR text string
- PCM / image bytes は CBOR byte string (`bstr`)
- tool schema や extension payload は CBOR map / array

### JSON を避ける理由

- audio / image が base64 化される
- message size と GC pressure が増える
- Dart/Java 双方で binary payload の二重変換が増える

### 独自バイナリ規則を増やさない理由

- 自前 varint / TLV / bit packing は実装差異を呼びやすい
- protocol の正当性検証が難しくなる
- Quarkus 側のデバッグ性が悪い

CBOR はこの中間にある、十分に標準的で binary friendly な選択肢である。

## Common Envelope

以下は **CBOR 診断表記** による説明であり、wire 上で JSON を使う意味ではない。

```text
{
  "type": "thread.patch",
  "streamSeq": 481,         ; server->client の stateful message のみ
  "body": { ... }
}
```

### 共通 field

| field | type | 必須 | 説明 |
| --- | --- | --- | --- |
| `type` | text | yes | message kind |
| `messageId` | text | request/response 相関が必要な送信 | reply 用相関キー |
| `streamSeq` | uint | server->client stateful message | server 送信列の単調増加番号 |
| `replyTo` | text | direct response のみ | 応答先 `messageId` |
| `body` | map | yes | type ごとの payload |

### ID ルール

- ASCII のみ
- 1..64 文字
- 予約文字の意味付けはしない
- UUIDv7 / ULID / snowflake のどれでもよい

### `messageId`

- `messageId` は request/response 相関が必要な送信だけに付ける
- 典型例は `session.open`, `session.instructions.set`, `turn.*.submit`, `tools.set`, `session.extension.apply`, `tool.result.submit`, `thread.sync.request`
- `live.audio.chunk`, `assistant.interrupt`, `thread.patch`, `thread.snapshot`, `assistant.audio.chunk`, `vad.state` のような one-way message には通常付けない
- `ack` と `error` は `replyTo` を持てば十分であり、自身の `messageId` は通常不要

### `streamSeq`

- session ごとに 1 から始まる単調増加整数
- `thread.snapshot`, `thread.patch`, `assistant.audio.chunk`, `assistant.audio.done`, `vad.state`, `error`, `session.ready`, `session.resumed` に付く
- client は最後に正常適用した `streamSeq` を保持する
- 健全な 1 本の WebSocket/TCP 接続の内部では transport-level packet loss は補正済みなので、`streamSeq` はその検出用ではない
- 主用途は reconnect 境界、client 側の処理落ち、server 側 replay 漏れ、revision 不整合の検知である

### Session identity

- active session は WebSocket connection context に束縛される
- したがって in-band message に毎回 `sessionId` を載せない
- `sessionId` は `session.ready`, `session.resumed`, `session.open.resume` で使う resume handle である

## Client To Server Messages

### `session.open`

session を初期化する。

```text
{
  "type": "session.open",
  "messageId": "...",
  "body": {
    "token": "<jwt>",
    "modelId": "voice-agent-prod",
    "voice": "alloy",
    "instructions": "...",
    "audioTurnMode": "voice_activity",
    "inputAudio": {
      "encoding": "pcm_s16le",
      "sampleRate": 24000,
      "channels": 1
    },
    "outputAudio": {
      "encoding": "pcm_s16le",
      "sampleRate": 24000,
      "channels": 1
    },
    "resume": {
      "sessionId": "s_01",
    },
    "client": {
      "platform": "flutter",
      "appVersion": "..."
    }
  }
}
```

`voice` と `instructions` は nullable。

`resume` は任意。含めない場合は新規 session 開始を意味する。

`token` は required な JWT であり、VHRP/1 における唯一の application-level authentication credential である。


### `audio.turn.mode.set`

```text
{
  "type": "audio.turn.mode.set",
  "body": {
    "mode": "voice_activity" | "manual"
  }
}
```

### `session.instructions.set`

mid-session instructions 更新。

```text
{
  "type": "session.instructions.set",
  "messageId": "...",
  "body": {
    "instructions": "..."   ; nullable
  }
}
```

規則:

- update 後の instructions は subsequent responses に適用される
- in-flight generation を遡及的に書き換える意味は持たない

### `live.audio.chunk`

`bindAudioInput()` で接続された live microphone PCM を送る。`voice_activity` mode のときだけ有効。

```text
{
  "type": "live.audio.chunk",
  "body": {
    "pcm": h'....',
    "sequence": 1842
  }
}
```

ルール:

- `pcm` は 24kHz / mono / 16-bit little-endian
- chunk 長は 10ms から 100ms を推奨
- server は `sequence` 欠落を error にしてよい
- server は chunk ごとに ack しない
- server は `manual` mode 中に受けた `live.audio.chunk` を黙って破棄してよい

### `turn.audio.submit`

manual 収録済みの 1 turn 分 audio を送る。

```text
{
  "type": "turn.audio.submit",
  "messageId": "...",
  "body": {
    "clientItemId": "item_user_01",
    "pcm": h'....',
    "sampleRate": 24000,
    "channels": 1,
    "bitDepth": 16
  }
}
```

### `turn.text.submit`

```text
{
  "type": "turn.text.submit",
  "messageId": "...",
  "body": {
    "clientItemId": "item_user_02",
    "text": "こんにちは"
  }
}
```

### `turn.image.submit`

```text
{
  "type": "turn.image.submit",
  "messageId": "...",
  "body": {
    "clientItemId": "item_user_03",
    "imageBytes": h'....'
  }
}
```

備考:

- MIME type は adapter ではなく backend が magic bytes から判定する
- backend は asset URL を thread patch に反映する

### `tools.set`

```text
{
  "type": "tools.set",
  "messageId": "...",
  "body": {
    "tools": [
      {
        "name": "document_read",
        "description": "Read document contents",
        "parameters": { ... JSON Schema compatible map ... }
      }
    ]
  }
}
```

`registerTools([])` は空配列を送る。

### `session.extension.apply`

```text
{
  "type": "session.extension.apply",
  "messageId": "...",
  "body": {
    "extensionType": "session.reasoning_effort_selection",
    "payload": {
      "selection": "medium"
    }
  }
}
```

v1 で想定する hosted extension:

- `session.voice_selection`
- `session.input_noise_reduction_selection`
- `session.reasoning_effort_selection`
- `session.tool_choice_required`

### `tool.result.submit`

```text
{
  "type": "tool.result.submit",
  "messageId": "...",
  "body": {
    "clientItemId": "item_tool_out_01",
    "callId": "call_01",
    "output": "{\"ok\":true}",
    "disposition": "success" | "error",
    "errorMessage": "..."   ; 任意
  }
}
```

`output` は **opaque UTF-8 string** として扱う。backend は valid JSON を要求しない。

### `assistant.interrupt`

```text
{
  "type": "assistant.interrupt",
  "body": {
    "reason": "barge_in"
  }
}
```

意味:

- 現在 generation 中の assistant 生成を止める
- 以降 stale generation 由来の audio/text/tool-call event を client に流さない

### `thread.sync.request`

reconnect 境界、revision mismatch、実装上の desync に対する再同期要求。

```text
{
  "type": "thread.sync.request",
  "messageId": "...",
  "body": {
    "afterStreamSeq": 480,
    "knownThreadRevision": 88,
    "mode": "delta_or_snapshot" | "snapshot_only",
    "reason": "gap_detected"
  }
}
```

意味:

- `delta_or_snapshot`: log が残っていれば replay、無ければ snapshot
- `snapshot_only`: 常に最新正規状態の I-frame を要求

## Server To Client Messages

### `session.ready`

```text
{
  "type": "session.ready",
  "replyTo": "<session.open.messageId>",
  "streamSeq": 1,
  "body": {
    "sessionId": "s_01",
    "threadId": "t_01",
    "conversationId": "c_01",
    "capabilities": {
      "extensions": [
        "session.input_noise_reduction_selection",
        "session.reasoning_effort_selection",
        "session.tool_choice_required"
      ]
    }
  }
}
```

### `session.resumed`

resume 成功時の応答。

```text
{
  "type": "session.resumed",
  "replyTo": "<session.open.messageId>",
  "streamSeq": 481,
  "body": {
    "sessionId": "s_01",
    "threadId": "t_01",
    "conversationId": "c_01",
    "resumeStrategy": "replay" | "snapshot",
    "threadRevision": 88
  }
}
```

この直後に server は次のどちらかを送る。

- `streamSeq > afterStreamSeq` の replay 群
- 最新 `thread.snapshot`

### `ack`

一般的な成功応答。

```text
{
  "type": "ack",
  "replyTo": "<client.messageId>",
  "body": {
    "accepted": true,
    "clientItemId": "item_user_02",
    "applied": true
  }
}
```

`body` の意味は `replyTo` 対象に依存する。

### `thread.snapshot`

初期状態または再同期用の authoritative I-frame。

```text
{
  "type": "thread.snapshot",
  "streamSeq": 481,
  "body": {
    "threadId": "t_01",
    "conversationId": "c_01",
    "snapshotKind": "i_frame",
    "threadRevision": 88,
    "items": [ ... ]
  }
}
```

規則:

- snapshot は canonical 最新状態を表す
- snapshot を受けた client はローカル thread を丸ごと置き換える
- snapshot は historical PCM 全量を必須にしない
- audio part は transcript のみ保持し、`audioChunks` が空でもよい

最後の 2 点により、欠落回復の主対象は「意味状態」であって「すでに失われた再生波形の完全再現」ではない。

### `thread.patch`

`RealtimeThread` に対する正規 mutation stream。

```text
{
  "type": "thread.patch",
  "streamSeq": 482,
  "body": {
    "patchKind": "p_frame",
    "baseThreadRevision": 88,
    "targetThreadRevision": 89,
    "ops": [
      { "op": "add_item", "item": { "id": "item_a", "type": "message", "role": "assistant", "status": "in_progress" } },
      { "op": "put_part", "itemId": "item_a", "contentIndex": 0, "part": { "type": "text", "isDone": false } },
      { "op": "append_text", "itemId": "item_a", "contentIndex": 0, "delta": "こんにちは" },
      { "op": "set_status", "itemId": "item_a", "status": "completed" }
    ]
  }
}
```

#### `ops` 一覧

| op | 必須 field | 効果 |
| --- | --- | --- |
| `add_item` | `item` | item を追加 |
| `remove_item` | `itemId` | item を削除 |
| `set_status` | `itemId`, `status` | item status 更新 |
| `set_role` | `itemId`, `role` | role 更新 |
| `set_field` | `itemId`, `field`, `value` | `callId`, `name`, `arguments`, `output`, `toolOutputDisposition`, `toolErrorMessage` を設定 |
| `put_part` | `itemId`, `contentIndex`, `part` | part を upsert |
| `append_text` | `itemId`, `contentIndex`, `delta` | text delta 追加 |
| `replace_text` | `itemId`, `contentIndex`, `text` | text 全置換 |
| `append_transcript` | `itemId`, `contentIndex`, `delta` | audio transcript delta 追加 |
| `replace_transcript` | `itemId`, `contentIndex`, `text` | audio transcript 全置換 |
| `set_conversation_id` | `conversationId` | thread conversationId 更新 |

`part` の shape:

- text part: `{ "type": "text", "isDone": false }`
- audio part: `{ "type": "audio", "isDone": false }`
- image part: `{ "type": "image", "imageUrl": "...", "detail": "auto" }`

idempotency rule:

- `add_item` の `item.id` が receiver 側にすでに存在する場合、duplicate add ではなく merge として扱う
- これにより optimistic user item と server canonical echo は同一 item ID を安全に共有できる

revision rule:

- `thread.patch.body.baseThreadRevision` は client の現在 revision と一致しなければならない
- 不一致なら client はその patch を適用せず `thread.sync.request` を送る

apply rule:

- receiver は `thread.patch` を atomic apply する実装を推奨される
- ただし protocol は rollback semantics まで強制しない
- どの実装方式であっても、1 op でも適用不能なら receiver は残りの op を信用せず `thread.sync.request` に移行すべきである

### `assistant.audio.chunk`

assistant PCM を運ぶ。adapter はこれを playback stream にそのまま流し、同時に対応 `RealtimeThreadAudioPart` へ base64 変換して蓄積してよい。

```text
{
  "type": "assistant.audio.chunk",
  "streamSeq": 483,
  "body": {
    "itemId": "item_a",
    "contentIndex": 1,
    "pcm": h'....'
  }
}
```

事前条件:

- 対応する `audio` part は `thread.patch/put_part` 済みであること
- client は `assistant.interrupt` 後、現在の active assistant item から外れた `itemId` を参照する late chunk を破棄してよい

### `assistant.audio.done`

```text
{
  "type": "assistant.audio.done",
  "streamSeq": 484,
  "body": {
    "itemId": "item_a",
    "contentIndex": 1
  }
}
```

### `vad.state`

```text
{
  "type": "vad.state",
  "streamSeq": 485,
  "body": {
    "isSpeaking": true
  }
}
```

### `error`

recoverable / unrecoverable 共通の application error。

```text
{
  "type": "error",
  "streamSeq": 486,
  "replyTo": "<client.messageId>",
  "body": {
    "code": "media.unsupported_image",
    "message": "Unsupported image format.",
    "recoverable": true
  }
}
```

推奨 error code:

- `auth.invalid_jwt`
- `session.unknown_model`
- `protocol.bad_message`
- `protocol.unsupported_message_type`
- `media.audio_format_mismatch`
- `media.unsupported_image`
- `tool.call_not_found`
- `extension.unsupported`
- `generation.interrupted`
- `resume.not_available`
- `state.out_of_sync`

v1 では application-level heartbeat message は定義しない。transport-level keepalive は WebSocket ping/pong に委ねる。

## Checkpoint Model

VHRP/1 は thread state を video codec 的に次の 2 種で扱う。

- `thread.patch`: P-frame
- `thread.snapshot`: I-frame

期待する動作:

1. 通常時は patch を継続適用する
2. reconnect や application-level desync 検知時は replay を試みる
3. replay できなければ snapshot へフォールバックする

client は任意タイミングで `thread.sync.request(mode=snapshot_only)` を送って I-frame を明示要求してよい。

## Thread Projection Rules

### user text

1. client が `turn.text.submit`
2. server が `ack`
3. server が `thread.patch` で user message item を completed として追加
4. server が assistant item を追加し、text/audio の delta を流す

### user audio one-shot

1. client が `turn.audio.submit`
2. server が user audio item を追加
3. server が transcript を得たら `append_transcript` / `replace_transcript`
4. server が assistant response を開始

### tool call

1. server は 1 generation 中に 0..N 個の `functionCall` item を出してよい
2. 各 call は `callId`, `name`, `arguments` を設定され、`set_status=completed` になった時点で executable になる
3. client は各 call ごとに tool 実行し `tool.result.submit` を返す
4. server は同一 generation の pending tool output が全て揃うまで次の assistant turn を開始しない (この「次 turn を開始しない」をどう実現するかは driver 依存であり、wire は振る舞いだけを定める)
5. server が `clientItemId` を優先して `functionCallOutput` item を追加し、次の assistant turn を開始する

補足:

- tool call の input materialization は逐次的でよい
- barrier をかけるのは tool output 側だけである

## Gap Detection And Recovery

client は次のどちらかを検知したら desync とみなす。

- 受信 `streamSeq` が `lastAppliedStreamSeq + 1` にならない
- `thread.patch.baseThreadRevision != localThreadRevision`

補足:

- 健全な同一 WebSocket connection の内部で前者が起きるなら、それは transport packet loss ではなく実装バグか reconnect 境界の扱いミスである
- この仕組みは TCP の再送制御を置き換えるものではなく、application state の整合性を守るためのものだ

desync 時の client 動作:

1. 以降の `thread.patch` と `assistant.audio.chunk` の増分適用を一時停止
2. `thread.sync.request(afterStreamSeq=<lastApplied>, knownThreadRevision=<local>)` を送る
3. server replay を受けられれば適用する
4. replay 不能なら `thread.snapshot` で置換する

resume 時も同じ機構を使う。違いは `thread.sync.request` を送る前に `session.open.resume` を行う点だけである。

## Interrupt Rule

`assistant.interrupt` を受けた server は、現在進行中の generation を中断し、以降その「旧 generation」由来の出力を client へ流してはならない。これは観測可能な契約であり、server がどう旧世代を識別・破棄するか (generation counter 等) は実装の自由である。具体的には:

- 旧 generation の text delta は client へ流さない
- 旧 generation の audio chunk は client へ流さない
- 旧 generation に紐づく未送信 tool call は client に流さない
- すでに流れた pending tool call は client 側 `cancelFunctionCalls()` で local incomplete 化する

## Size Limits

v1 推奨値:

- `turn.text.submit.text`: 16 KiB UTF-8 以内
- `turn.image.submit.imageBytes`: 8 MiB 以内
- `turn.audio.submit.pcm`: 2 MiB 以内
- `live.audio.chunk.pcm`: 16 KiB 以内
- `tools.set.tools`: 64 個以内

## Forward Compatibility

- 未知の `type` は `error(protocol.unsupported_message_type)` を返す
- `body` 内の未知 field は無視してよい
- `thread.patch.ops[].op` の未知値は protocol error
- `thread.patch.baseThreadRevision` 不一致時にそのまま適用してはならない
