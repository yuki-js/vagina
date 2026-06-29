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
  "body": { ... }
}
```

### 共通 field

| field | type | 必須 | 説明 |
| --- | --- | --- | --- |
| `type` | text | yes | message kind |
| `messageId` | text | request/response 相関が必要な送信 | reply 用相関キー |
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

### 状態同期は単一回復経路に集約する

VHRP/1 は server 送信列に番号 (`streamSeq`) を振らず、thread に revision も持たない。理由はこうである。

- 健全な 1 本の WebSocket/TCP 接続の内部では transport-level packet loss は補正済みなので、順序や欠落をアプリ層で検知する番号は不要である
- `thread.patch` は **fire-and-forget なライブ差分** であり、適用前に照合すべきバージョンを持たない
- 何らかの理由で差分が届かず client 投影がズレうる唯一の境界は、frame を配信できない事態と reconnect である。これらはいずれも **最新の full `thread.snapshot` で投影を丸ごと作り直す** ことで回復する

したがって gap 検知・replay・楽観ロック的な revision 照合はいずれも存在しない。配信不能や再同期はすべて「`thread.snapshot` を取り直す」一本道に畳み込まれる (後述 Recovery Model)。

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

`disposition` は tool result の canonical status であり、`success` は正常完了、`error` は失敗完了を意味する。`output` は **opaque UTF-8 string** として扱う。backend は valid JSON を要求せず、canonical status 判定のために `output` を JSON として解釈してはならない。互換性のため `disposition` が欠落した場合は `success` とみなす。`disposition:error` の場合、`errorMessage` は UI 表示・診断用の canonical error message である。

server は `tool.result.submit` を canonical thread に投影するとき、対応する `functionCallOutput` item に `toolOutputDisposition` (`success` | `error`) と、存在する場合は `toolErrorMessage` を必ず反映する。`thread.patch` と `thread.snapshot` は同じ canonical projection を使い、UI は `output` の JSON parse ではなくこれらの canonical fields を primary source として error/success を描画する。

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

reconnect 直後や実装上の desync に対する再同期要求。cursor や revision は載せない。応答は常に最新の full `thread.snapshot` であり、部分 catch-up は存在しない。`reason` は診断用の任意ヒントにすぎない。

```text
{
  "type": "thread.sync.request",
  "messageId": "...",
  "body": {
    "reason": "reconnected"
  }
}
```

意味:

- server は現在の正規 thread 全体を `thread.snapshot` として返す
- client はローカル投影をその snapshot で丸ごと置換する

## Server To Client Messages

### `session.ready`

```text
{
  "type": "session.ready",
  "replyTo": "<session.open.messageId>",
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

resume 成功時の応答。rebind の成立通知に徹する。

```text
{
  "type": "session.resumed",
  "replyTo": "<session.open.messageId>",
  "body": {
    "sessionId": "s_01",
    "threadId": "t_01",
    "conversationId": "c_01"
  }
}
```

server はこの直後に状態を自動送信しない。`session.resumed` を受けた client は `thread.sync.request` を送り、server が返す最新 full `thread.snapshot` でローカル投影を丸ごと作り直す。cursor も revision も resume strategy も載らない。回復は常に full snapshot 一本道だからである。

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

初期状態または再同期用の authoritative な full thread 状態。これが唯一の回復プリミティブである。

```text
{
  "type": "thread.snapshot",
  "body": {
    "threadId": "t_01",
    "conversationId": "c_01",
    "items": [ ... ]
  }
}
```

規則:

- snapshot は canonical 最新状態を表す
- snapshot を受けた client はローカル thread を丸ごと置き換える
- snapshot は historical PCM 全量を必須にしない
- audio part は transcript のみ保持し、`audioChunks` が空でもよい
- snapshot は revision や sequence を持たない。「今の正規状態」そのものであり、照合すべきバージョンを必要としない

最後の 2 点により、欠落回復の主対象は「意味状態」であって「すでに失われた再生波形の完全再現」ではない。

### `thread.patch`

`RealtimeThread` に対するライブ mutation stream。fire-and-forget であり、revision も sequence も持たない。届かなかった場合の回復は patch の照合ではなく、reconnect + 最新 `thread.snapshot` の取り直しである。

```text
{
  "type": "thread.patch",
  "body": {
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

`functionCallOutput` item の canonical fields:

- `output`: opaque tool output string。表示詳細や provider 送信用の payload であり、status 判定の primary source ではない。
- `toolOutputDisposition`: canonical status。`success` または `error`。古い sender との互換性のため欠落時は receiver 側で `success` とみなしてよい。
- `toolErrorMessage`: `toolOutputDisposition:error` のときの human-readable error message。存在しない場合でも status は `toolOutputDisposition` に従う。

idempotency rule:

- `add_item` の `item.id` が receiver 側にすでに存在する場合、duplicate add ではなく merge として扱う
- これにより optimistic user item と server canonical echo は同一 item ID を安全に共有できる

apply rule:

- `thread.patch` は revision を持たない。receiver は到着した op をそのままローカル投影に適用する (照合すべきバージョンはない)
- receiver は `thread.patch` を atomic apply する実装を推奨される
- ただし protocol は rollback semantics まで強制しない
- どの実装方式であっても、1 op でも適用不能なら receiver は残りの op を信用せず `thread.sync.request` を送り、返ってくる full `thread.snapshot` で投影を作り直す

### `assistant.audio.chunk`

assistant PCM を運ぶ。adapter はこれを playback stream にそのまま流し、同時に対応 `RealtimeThreadAudioPart` へ base64 変換して蓄積してよい。

```text
{
  "type": "assistant.audio.chunk",
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

v1 では application-level heartbeat message は定義しない。transport-level keepalive は WebSocket ping/pong に委ねる。

## Recovery Model

VHRP/1 の状態同期は単一の回復経路に集約される。

- `thread.patch`: ライブ差分。fire-and-forget で、revision も sequence も持たない
- `thread.snapshot`: 唯一の回復プリミティブ。常に最新の正規 thread 全体

期待する動作:

1. 通常時は patch を継続適用する
2. reconnect 直後・実装上の desync・patch の適用不能を検知したら `thread.sync.request` を送る
3. server が返す最新 `thread.snapshot` でローカル投影を丸ごと作り直す

replay も部分 catch-up も存在しない。client は不安な時はいつでも `thread.sync.request` を送って最新 snapshot を取り直してよい。

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

## Recovery Triggers

VHRP/1 は番号や revision による gap 検知を持たない。健全な 1 本の WebSocket/TCP 接続の内部では順序と無損失が保証されるので、アプリ層で欠落を検知する必要がないからである。

代わりに、投影がズレうる事象は次のいずれかであり、すべて同一の回復に畳み込まれる。

- reconnect (瞬断後の再接続。恒久的なソケット障害もここに含まれる。server は live frame 配信失敗を能動 close せず握り潰すが、本当に切れたソケットは framework が検知して切断するため、結局 reconnect に帰着する)
- patch の op が適用不能だったとき

client 動作:

1. `thread.sync.request` を送る
2. server が返す最新 `thread.snapshot` でローカル投影を丸ごと置換する

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
- op が適用不能なら残りを信用せず `thread.sync.request` を送って full snapshot を取り直す
