# Adapter Boundary

## 参照元

この仕様は主に次のコードから導出した。

- [`realtime_adapter.dart`](../../lib/feat/call/services/realtime/realtime_adapter.dart)
- [`realtime_thread.dart`](../../lib/feat/call/models/realtime/realtime_thread.dart)
- [`realtime_service.dart`](../../lib/feat/call/services/realtime_service.dart)
- [`call_service.dart`](../../lib/feat/call/services/call_service.dart)

## 境界として見える能力

`RealtimeAdapter` が外に見せている能力は次の 10 系統だけである。

1. connection lifecycle
2. accumulated thread projection
3. live microphone ingestion
4. assistant PCM output
5. VAD speaking state
6. tool catalog registration
7. instructions update
8. opaque provider extension update
9. user content submission
10. response interruption

この 10 系統以外の結合点は、少なくとも現行アプリには存在しない。したがって hosted backend もこの境界だけを満たせばよく、vendor 固有の request 名や patch 形式をアプリ全体に漏らす必要はない。

## Method To Responsibility Mapping

| Adapter API | backend に必要な責務 | wire primitive |
| --- | --- | --- |
| `connect()` | model 選択、voice/instructions 設定、session 開始 | `session.open` |
| `dispose()` | graceful close、リソース解放 | WebSocket close |
| `bindAudioInput()` | live PCM chunk 受信の開始停止 | `live.audio.chunk` |
| `setAudioTurnMode()` | VAD / manual の切り替え | `audio.turn.mode.set` |
| `assistantAudioStream` | assistant PCM chunk 配信 | `assistant.audio.chunk` |
| `assistantAudioCompleted` | 現在の assistant 音声境界通知 | `assistant.audio.done` |
| `isUserSpeaking` | server-side VAD 状態 | `vad.state` |
| `registerTools()` | tool catalog の session 反映 | `tools.set` |
| `setInstructions()` | session instructions の更新 | `session.instructions.set` |
| `applyProviderExtension()` | extension key/value を backend が解釈 | `session.extension.apply` |
| `sendAudioOneShot()` | 1 つの完結した user audio turn を投入し応答開始 | `turn.audio.submit` |
| `sendText()` | user text turn を投入し応答開始 | `turn.text.submit` |
| `sendImage()` | image asset を投入し応答開始 | `turn.image.submit` |
| `sendFunctionOutput()` | tool 実行結果を callId に対して返す | `tool.result.submit` |
| `cancelFunctionCalls()` | local thread projection の stale tool call を無効化 | local-only |
| `interrupt()` | 生成停止、buffered output audio 破棄 | `assistant.interrupt` |

## `RealtimeThread` から見える不変条件

### 1. item type は 3 種のみ

- `message`
- `functionCall`
- `functionCallOutput`

wire protocol でもこの 3 種をそのまま採用する。ここに vendor native concept を増やさない。

### 2. content part は text / audio / image

message item の part は次の 3 種だけである。

- `text`
- `audio`
- `image`

`audio` part は transcript を持てる。つまり backend は「音声そのもの」と「その文字化」を別イベントとして送れる必要がある。

### 3. status 遷移は一方向

item status は次の 3 値だけであり、通常は `in_progress -> completed` または `in_progress -> incomplete` へ進む。

- `in_progress`
- `completed`
- `incomplete`

特に `CallService` は **completed な functionCall item だけ** を tool 実行対象として扱う。したがって backend は tool call の item を「未完成の途中状態」で見せるなら、実行可能になった時点で必ず `completed` にしなければならない。

### 4. function call は `callId` が主キー

- `functionCall` item は `callId`, `name`, `arguments` を持つ。
- `functionCallOutput` item は同じ `callId` にぶら下がる。
- `sendFunctionOutput()` の引数も `callId` ベースであり、itemId ではない。

backend は `callId` を session 内で一意に保つ必要がある。

### 5. assistant audio completion は item completion と別概念

`assistantAudioCompleted` は playback 制御のための信号であり、thread item の `completed` とイコールではない。よって wire protocol でも `assistant.audio.done` を独立イベントとして持つ。

### 6. image part は raw bytes を保持しない

`RealtimeThreadImagePart` は `imageUrl` と `detail` を保持する。つまり `sendImage()` で渡された bytes を thread に残す責務は adapter ではなく backend 側の asset 化にある。

必要条件:

- backend は受信画像を一時 asset として保存できること
- thread には asset URL もしくは stable handle を入れること
- Flutter 側 UI には文字列として表示可能な値を返すこと

### 7. tool cancel は projection concern

`cancelFunctionCalls()` は `void` であり、コメントも local projection 向けである。したがって v1 では wire で独立メッセージにしない。stale response の抑止は `assistant.interrupt` 後の generation 切り替えで吸収する。

## 仕様上の含意

### Session は backend 主導で thread を正規化する

thread は semi-mutable だが、正規形は backend が持つ。adapter は patch を適用してローカル投影を保つだけにする。

この設計だと、local state が壊れたり event の一部を取りこぼしても server 正規形から回復できるべきである。したがって wire protocol には少なくとも次が必要になる。

- server 送信列の単調増加番号 `streamSeq`
- canonical thread 全体の revision `threadRevision`
- 差分再送の `thread.patch`
- 正規全体像の `thread.snapshot`

なお active な session 自体は WebSocket connection context で一意に識別できる。したがって in-band message に毎回 `sessionId` を載せる必要はない。`sessionId` は resume handshake のための handle としてだけ使えばよい。

### user item ID は client 先行でよい

`sendText()`, `sendAudioOneShot()`, `sendImage()`, `sendFunctionOutput()` は戻り値で local item ID を返す。したがって client は item ID を先に採番し、wire で backend に伝え、backend はその ID を尊重する設計がよい。

### backend は vendor translation layer を内部に閉じる

model provider, ASR, TTS, VAD, tool orchestration は backend 内の driver に隠蔽する。Flutter 側に provider-specific field を増やさない。

この方針の例外は `setInstructions()` だけである。instructions だけは current adapter contract に mid-session mutation API を追加した。一方 voice 変更は adapter contract には増やさず、`applyProviderExtension()` の extension key で扱う。

### resume / resync は adapter 境界の外で吸収できる

現行 adapter 界面には resume 専用 API がない。それでも問題はない。unexpected disconnect 時の reconnect、gap 検知後の snapshot 要求、replay fallback は adapter 実装の内側で完結できるからである。

つまり追加すべきなのは Flutter 公開 API ではなく、wire contract と adapter 内部状態である。
