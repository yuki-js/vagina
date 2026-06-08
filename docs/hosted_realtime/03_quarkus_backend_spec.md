# Quarkus Backend Spec

## 目的

ここでいう backend は、Flutter app と model provider 群の間に立つ hosted realtime service である。責務は次の 4 つに限定する。

1. app 固有 protocol `VHRP/1` の終端
2. session / thread / tool-call の整合性維持
3. model/ASR/TTS/VAD driver の隠蔽
4. asset と認証の管理

## 実装方針

### 推奨構成

- WebSocket: realtime session 本体
- binary codec: CBOR
- session state: メモリ or 外部 store
- replay log + snapshot checkpoint
- audio/image asset: object storage
- model integration: backend 内部 SPI

### 採用しないもの

- 独自 TCP protocol
- HTTP polling
- gRPC streaming を Flutter adapter へ直接露出
- vendor native event 名の透過

## Public API

### `GET /api/hosted-realtime/v1/connect`

WebSocket upgrade endpoint。

要件:

- `Sec-WebSocket-Protocol: vhrp.cbor.v1`
- application-layer では upgrade 時認証を要求しない
- 接続後の最初の application message は `session.open` でなければならない
- `session.open.body.token` に載る JWT を検証して session context を生成する

upgrade 後の active session は WebSocket connection context に束縛される。in-band frame に毎回 `sessionId` を載せる必要はない。

補足:

- WebSocket 以外の REST endpoint が JWT を使うかどうかは本 protocol の外である
- JWT refresh と WebSocket connection lifetime の連動規則は定義しない
- application-level heartbeat は v1 では定義せず、keepalive は WebSocket ping/pong に委ねる

## Quarkus Component Layout

### `HostedRealtimeSocketEndpoint`

WebSocket endpoint。責務:

- binary frame 受信
- CBOR decode
- `type` ごとの dispatch
- connection context から active session を解決
- session close

イベントループ上で重い処理をしない。decode 後の model call, transcription, asset upload, tool wait は worker 側へ逃がす。

### `HostedSessionCoordinator`

session ごとの orchestrator。責務:

- session state machine
- `streamSeq` / `threadRevision` / `itemRevision` 管理
- current generation 管理
- turn mode 管理
- active tool catalog
- pending tool call 管理
- resume handle としての `sessionId` 管理
- current instructions 管理

### `ThreadProjector`

server 正規状態から `thread.patch` / `thread.snapshot` を生成する。Flutter 側 `RealtimeThread` と 1 対 1 で対応する event のみを出す。

### `ReplayLog`

責務:

- 最近送った `streamSeq` 付き server message を session ごとに保持
- `afterStreamSeq` からの replay 可否を判定
- retention window 外なら snapshot fallback を指示

### `CheckpointStore`

責務:

- `thread.snapshot` の生成元となる canonical thread state を保持
- `threadRevision` と item revision index を保持
- transport 欠落時の authoritative resync を支える

### `AudioIngressService`

責務:

- `live.audio.chunk` の sequence 検証
- PCM format 検証
- VAD 用 buffer 管理
- manual / voice-activity mode の切り替え
- `manual` mode 中に受けた `live.audio.chunk` の黙殺

### `AssistantAudioEgressService`

責務:

- TTS あるいは model audio 出力の PCM chunk 化
- `assistant.audio.chunk`
- `assistant.audio.done`

### `ToolCallBroker`

責務:

- model からの tool request を `functionCall` item に変換
- `callId` 採番
- generation ごとの pending tool queue を管理
- `tool.result.submit` 待機
- timeout / generation 失効処理

### `AssetService`

責務:

- `turn.image.submit` の bytes を object storage に保存
- content type 判定
- asset URL 発行
- TTL 管理

## Session State Machine

```text
NEW
  -> OPENING
  -> READY
  -> ACTIVE
  -> DETACHED
  -> INTERRUPTING
  -> CLOSING
  -> CLOSED
```

補助 state:

- `streamSeq`: `long`
- `generation`: `long`
- `threadRevision`: `long`
- `audioTurnMode`: `voice_activity | manual`
- `liveInputBound`: boolean

`DETACHED` は transport が切れたが session 自体は保持している状態である。grace period 内なら `session.resumed` で `ACTIVE` に戻れる。

### generation rule

`assistant.interrupt` ごとに `generation` を increment する。model, TTS, transcription, tool wait の各 async task は generation を捕捉し、completion 時に current generation と一致しなければ output を捨てる。

これで Flutter 側の `cancelFunctionCalls()` と整合する。

### resume / resync rule

server は session ごとに次を持つ。

- bounded replay log
- 最新 canonical thread
- `threadRevision`
- item ごとの revision

resume 時:

1. `session.open.resume.afterStreamSeq` を受ける
2. replay log が残っていれば replay
3. 残っていなければ `thread.snapshot`
4. session 自体が失効していれば `resume.not_available`

これが、断片欠落と transport reconnect を同一メカニズムで扱う中心設計である。

補足:

- WebSocket/TCP 自体は active connection 内の順序と再送を保証する
- したがって `streamSeq` は packet loss 対策ではなく、reconnect 境界と application-state continuity のためにある

## Model Driver SPI

backend の内部では vendor 差分を次の SPI に閉じ込める。

```text
ModelDriver
  openSession()
  closeSession()
  submitUserText()
  submitUserAudio()
  submitUserImage()
  updateInstructions()
  updateTools()
  applyExtension()
  interruptGeneration()
  resumeAfterToolResult()
```

driver が返すイベントも backend 内の抽象イベントに正規化する。

```text
AssistantTextDelta
AssistantAudioChunk
AssistantTranscriptDelta
ToolCallRequested
TurnCompleted
ModelProblem
```

WebSocket へ直接 vendor event を流さない。

## Replay And Checkpoint Policy

最低限必要なポリシー:

- replay log は直近 N 件または M 秒保持
- `threadRevision` は thread を変えるたび increment
- `itemRevision` は対象 item を変えるたび increment
- snapshot checkpoint は少なくとも最新 1 個を保持

推奨:

- replay log: 2,000 message または 2 分
- checkpoint 更新: 25 revision ごと、または 1 秒ごと

完全 event sourcing は不要だが、resume を名乗るなら replay log と最新 checkpoint は必要である。

## Quarkus-Specific Guidance

### WebSocket 実装

- 新規実装なら `WebSockets Next` を第一候補にする
- 既存コードが Jakarta WebSocket 前提なら legacy extension でもよい
- 重要なのは binary message を素直に扱えることだけで、API スタイルは backend 全体の既存規約に合わせる

### CBOR codec

- REST 用 JSON `ObjectMapper` とは分ける
- `CBORFactory` を使った dedicated mapper を 1 つ持つ
- DTO は sealed interface まで凝らず、flat POJO + validator で十分
- top-level envelope は `type` ベース dispatch のほうが簡単

### event loop を塞がない

避けるべきもの:

- WebSocket コールバック内での同期的 object storage upload
- 同期 HTTP client での model 呼び出し
- 巨大 byte array の繰り返し再コピー

方針:

- decode と軽い validation だけ event loop
- それ以外は worker
- PCM chunk は `byte[]` か `Buffer` で保持

### validation

必須 validation:

- 最初の application message が `session.open` であること
- `session.open.token` が JWT として妥当であること
- message size limit
- audio format
- image magic bytes
- `callId` が session 内 pending call を指すこと
- extension key / payload shape

unknown field を厳格 reject しすぎる必要はないが、`type` と `op` は厳格に扱う。

gap recovery では validation も追加で必要になる。

- `afterStreamSeq` が未来を指していないこと
- `knownThreadRevision` が整数であること
- replay 不能時は snapshot fallback すること
- `session.open.token` が存在し、policy に合致すること

## Tool Call Contract

### outbound

backend は model の tool request を次の順で thread に反映する。

1. `add_item(type=functionCall)`
2. `set_field(callId)`
3. `set_field(name)`
4. `set_field(arguments)`
5. `set_status(completed)`

### inbound

client から `tool.result.submit` を受けたら:

1. `callId` を pending call に照合
2. `clientItemId` があればそれを item ID として `functionCallOutput` item を追加
3. `output`, `toolOutputDisposition`, `toolErrorMessage` を設定
4. 同一 generation の pending tool queue が 0 なら assistant generation を再開

これは v1 の server policy である。incremental resume は採らない。

## Session Mutation Policy

### `session.instructions.set`

- subsequent responses にだけ適用する
- in-flight generation を遡及的に書き換えない

### `session.extension.apply(session.voice_selection)`

- voice 変更は explicit adapter API ではなく extension key 経由で扱う
- unsupported backend は `applied=false` または recoverable `error` を返してよい

## Image Handling

`sendImage()` が bytes しか持たないので、backend は必ず content sniffing を行う。

受理対象例:

- JPEG
- PNG
- WebP

非受理:

- SVG
- PDF
- arbitrary binary renamed as image

保存後、thread には URL を入れる。URL は public permanent URL である必要はなく、signed URL でも internal asset handle URL でもよい。ただし Flutter UI から文字列として識別できること。

## Persistence

v1 で永続化が必要なのは次だけでよい。

- session state store
- replay log
- latest thread checkpoint
- image asset store
- observability log

thread 全体の長期 durable persistence は必須ではないが、少なくとも **resume retention window 中** は replay log と最新 checkpoint を持つ必要がある。現行 app も session detail には要約済み chat history を保存しており、backend に完全 event sourcing を要求していない。

## Horizontal Scaling

素直な選択肢は 2 つ。

1. sticky session
2. 外部 session store + shared broker

短い reconnect だけなら sticky session でもよい。ただし resume を node 越しに成立させたいなら、少なくとも checkpoint と replay log は外部化する必要がある。

## Security Checklist

- unauthenticated socket open 自体は protocol 上許容する
- 最初の `session.open` 以外は close する
- `session.open.token` に載る JWT だけを application-layer credential として扱う
- message size limit を設定する
- image sniffing を必須にする
- tool result を string として扱い、server 側で危険な再解釈をしない
- interrupted generation の late event を必ず捨てる
- structured log に raw audio/image を出さない
