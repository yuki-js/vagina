# Flutter Adapter Implementation Plan

## 目的

ここでは hosted backend に対する Flutter 実装を、既存 [`RealtimeAdapter`](../../lib/feat/call/services/realtime/realtime_adapter.dart) に差し込む前提で整理する。

追加対象の主役は `HostedRealtimeAdapter` であり、`RealtimeAdapterFactory` の `HostedVoiceAgentApiConfig` 分岐に接続する。

## 推奨ファイル分割

- `lib/feat/call/services/realtime/hosted_realtime_adapter.dart`
- `lib/feat/call/services/realtime/hosted_realtime_socket_client.dart`
- `lib/feat/call/services/realtime/hosted_realtime_codec.dart`
- `lib/feat/call/services/realtime/hosted_realtime_thread_projector.dart`
- `lib/feat/call/services/realtime/hosted_realtime_ids.dart`

codec と thread mutation を adapter 本体から分ける。`RealtimeAdapter` 実装が巨大な状態機械 1 個に潰れるのを避けるためである。

## Adapter Internal State

最低限必要な state:

- `RealtimeThread _thread`
- connection state controller
- error controller
- thread update controller
- assistant audio controller
- assistant audio completed controller
- user speaking controller
- active websocket client
- live audio subscription
- current turn mode
- current resume handle `sessionId` / `threadId` / `conversationId`
- `lastAppliedStreamSeq`
- `threadRevision`
- `itemRevisionById`
- `generation` or `interruptionEpoch`
- `awaitingResync`
- reconnect backoff state
- pending request completers keyed by `messageId`

## Method Mapping

### `connect()`

1. app auth/session service から現在の JWT を取得する
2. WebSocket 接続を開く
3. `session.open` に JWT を載せ、resume 候補 session があれば `session.open.resume` も付けて送る
4. `session.ready` または `session.resumed` を待つ
5. 新規なら空 `RealtimeThread` を `threadId` ベースで初期化する
6. resume なら後続 replay か snapshot を待つ

失敗時:

- `connectionState = failed`
- `errors` に `RealtimeAdapterError` を流す

### `dispose()`

1. live audio subscription を解除
2. WebSocket を close
3. controller を閉じる
4. state を idempotent に `disconnected`

graceful dispose は resume 対象 session の破棄も意味する。unexpected disconnect だけが自動 resume 対象である。

### `bindAudioInput()`

責務は local stream binding のみ。

- 既存 subscription を解除
- `null` なら unbind
- 非 `null` なら購読開始
- `RealtimeAudioTurnMode.voiceActivity` かつ connected のときだけ `live.audio.chunk` を送る
- `manual` mode のときは stream は保持しても upstream へ流さない

### `setAudioTurnMode()`

- local state 更新
- connected なら `audio.turn.mode.set`
- live stream が bind 済みなら、その後の chunk forwarding 挙動を切り替える

### `registerTools()`

`ToolDefinition` 全体ではなく backend が必要とする 3 field へ射影する。

- `toolKey -> name`
- `description`
- `parametersSchema -> parameters`

応答は `ack.body.applied` がなくてもよいが、失敗は `error` で扱う。

### `setInstructions()`

- `session.instructions.set`
- update は subsequent responses にだけ効かせる
- in-flight generation の rewrite は期待しない

### `applyProviderExtension()`

- `session.extension.apply`
- `session.voice_selection` は voice 変更の標準 extension key とみなす
- `ack.body.applied == true` なら `true`
- `error(code=extension.unsupported)` または `ack.body.applied == false` なら `false`

### `sendText()`

1. local item ID を生成
2. optimistic に user message item を thread に追加
3. `turn.text.submit` を送る
4. server echo は同じ item ID で merge する
5. `ack` 失敗時は item を `incomplete` にする

### `sendAudioOneShot()`

1. local item ID を生成
2. local thread に user audio item を追加
3. `turn.audio.submit`
4. server echo は同じ item ID で merge する
5. transcript patch を待つ

thread 上の audio part は今の model に合わせて `audioChunks` を base64 で持つ。wire は binary なので、adapter 内でだけ base64 化する。

### `sendImage()`

1. local item ID を生成
2. optimistic item を作るが `imageUrl` は仮値にしない
3. `turn.image.submit`
4. backend からの `thread.patch/put_part(type=image)` を待つ

理由:

- `RealtimeThreadImagePart` は immutable に近く、あとから URL だけ差し替えるより server 正規値を待つほうが素直

### `sendFunctionOutput()`

1. local output item ID を生成
2. その ID を `clientItemId` として `tool.result.submit`
3. `ack` 後、server patch に任せる

output item を client で先に確定生成しないほうがよい。server が canonical な `functionCallOutput` item を作るからである。ただし戻り値の local ID と server item ID は一致させる。

### `cancelFunctionCalls()`

これは wire に送らない。

やること:

- 指定 `itemIds` の `functionCall` item を `incomplete`
- 指定 `callIds` に一致する pending call item も `incomplete`
- 以後その `callId` の late output を無視するため local set に積む

### `interrupt()`

1. local `generation` を進める
2. `assistant.interrupt` を送る
3. playback stream にはこれ以上古い chunk を流さない

### unexpected disconnect

adapter は unexpected close を検知したら、可能なら自動 reconnect を試みる。

送る resume 情報:

- `sessionId`
- `lastAppliedStreamSeq`
- `threadRevision`

resume 失敗時は fresh session を黙って作らず、`errors` に流して接続失敗として扱う。状態喪失を隠さないためである。

## Incoming Message Handling

### `thread.snapshot`

- `_thread.items` を再構築
- `conversationId` を設定
- `threadRevision` を置き換える
- `itemRevisionById` を snapshot の値で再構築する
- `lastAppliedStreamSeq` を更新する
- `awaitingResync = false`
- `threadUpdates` を emit

### `thread.patch`

`HostedRealtimeThreadProjector` で `ops` を順に適用する。apply 後に 1 回だけ `threadUpdates` を emit する。

注意:

- `streamSeq == lastAppliedStreamSeq + 1` を先に確認する
- `baseThreadRevision == localThreadRevision` を先に確認する
- 不一致なら patch を適用せず `thread.sync.request` を送る
- 同一の健全な WebSocket connection 内で `streamSeq` gap が見えたら、transport packet loss ではなく reconnect 境界か実装不整合とみなす
- projector は atomic apply 実装を推奨する
- ただし 1 op でも apply 不能なら残りを信用せず resync に移行すべきである
- `add_item` で既存 item ID が来た場合は duplicate append せず merge 扱いにする
- `put_part(type=audio)` を受けたら `RealtimeThreadAudioPart` を作る
- `append_transcript` は transcript のみ更新
- `set_field(toolOutputDisposition)` は enum へ変換
- apply 完了後に `threadRevision = targetThreadRevision`
- op に `itemRevision` があれば sidecar に反映する

### `assistant.audio.chunk`

1. stale generation なら破棄
2. `awaitingResync` 中なら破棄
3. interrupt 後に current active assistant item から外れた `itemId` なら破棄
4. `assistantAudioStream.add(pcm)`
5. 対応する `RealtimeThreadAudioPart.appendAudioDelta(base64Encode(pcm))`

### `assistant.audio.done`

- `assistantAudioCompleted.add(null)`
- 必要なら対象 audio part を `isDone=true`

### `vad.state`

- `isUserSpeaking` を更新

### `error`

- `errors.add(RealtimeAdapterError(...))`
- `replyTo` に対応する completer があれば fail
- unrecoverable なら接続を閉じる

### `session.resumed`

- `sessionId`, `threadId`, `conversationId` を再結合する
- `resumeStrategy=replay` なら replay を待つ
- `resumeStrategy=snapshot` なら直後の `thread.snapshot` を待つ

### `thread.sync.request`

local helper として次の条件で送る。

- `streamSeq` gap
- `baseThreadRevision` mismatch
- user が明示的に最新状態再取得を要求した場合

送信後:

- `awaitingResync = true`
- replay/snapshot が来るまで増分適用を止める

## Local IDs

user 起点 item は client 生成 ID を使う。

推奨 prefix:

- `msgu_` user message
- `msga_` assistant message
- `call_` function call correlation
- `toolout_` function output

prefix 自体に意味は持たせないが、デバッグしやすい。

## Testing Strategy

### 単体テスト

- CBOR envelope encode/decode
- `thread.patch` の op 適用
- `streamSeq` gap 検知
- `baseThreadRevision` mismatch で `thread.sync.request` を送ること
- `assistant.audio.chunk` が playback stream と thread の両方を更新すること
- `error(replyTo=...)` が pending completer を失敗させること
- `cancelFunctionCalls()` が local incomplete 化だけ行うこと

### 結合テスト

- text turn round-trip
- voice activity turn round-trip
- manual push-to-talk turn round-trip
- `setInstructions()` 後の subsequent response 反映
- tool call -> tool result -> assistant resume
- unexpected socket close -> `session.resumed` replay
- replay 不可 -> `thread.snapshot` fallback
- interrupt 中の stale audio/text drop
- unsupported extension returns false

### 回帰テスト

`CallService` が暗黙に依存しているのは次だけなので、ここを重点確認する。

- completed functionCall item のみ dispatch される
- `assistantAudioCompleted` で playback drain が閉じる
- `isUserSpeakingUpdates` で barge-in が動く

## Rollout Sequence

1. codec と thread projector を先に固定する
2. JWT を `session.open` に載せて認証するところまで実装する
3. text turn を最初に通す
4. assistant audio を通す
5. live audio / VAD を通す
6. tool round-trip を通す
7. resume / replay / snapshot fallback を通す
8. extensions と image を通す

この順なら、最初の milestone で `sendText()` と assistant 応答だけでも `RealtimeAdapterFactory` を hosted 実装へ差し替えられる。
