# Hosted Realtime Design Set

このディレクトリは、[`RealtimeAdapter`](../../lib/feat/call/services/realtime/realtime_adapter.dart) を唯一の外部契約として見なし、ホステッド版 realtime 実装の clean-room 設計をまとめたものです。

前提は次の 3 点です。

1. Flutter 側の provider 依存は adapter の内側に閉じる。
2. wire protocol は既存他社 API の語彙や payload を模倣しない。
3. Quarkus で素直に実装できる表現だけを採用する。

## 重要な設計判断

- transport は `wss` 上の独自 subprotocol とする。
- wire encoding は JSON ではなく CBOR とする。
- 音声と画像は CBOR の `bstr` に載せ、base64 化しない。
- thread 反映は provider 由来の event 名ではなく、`RealtimeThread` に対する patch 操作として定義する。
- thread 同期は 2 形式だけにする。`thread.patch` はライブ差分 (fire-and-forget・番号なし)、`thread.snapshot` は唯一の回復プリミティブ (常に最新の full 状態)。
- 投影がズレうる事象 (reconnect・配信失敗・op 適用不能) はすべて reconnect + 最新 `thread.snapshot` 取り直しの単一経路に畳み込む。`streamSeq` や thread revision は持たない。
- active session は WebSocket connection context に束縛し、`sessionId` は resume 用 handle に限定する。
- `messageId` は request/response 相関が必要なときだけ使う。
- 認証は `session.open.token` に載る JWT だけで行う。
- mid-session の `instructions` 更新は explicit message として持ち、`voice` 更新は extension 経由に寄せる。
- 同一 generation の tool output は queue が 0 になるまで barrier し、その後に assistant を再開する。
- application-level heartbeat は v1 に入れず、transport keepalive は WebSocket ping/pong に委ねる。
- function call は `RealtimeThreadItemType.functionCall` / `functionCallOutput` の往復で完結させる。

CBOR を選ぶ理由は単純です。JSON だと音声や画像で base64 が必須になり無駄が大きい一方、独自のビット列フォーマットを新規発明すると実装差分と脆弱性の温床になります。CBOR なら標準化済みで、Dart 側でも Java/Quarkus 側でも扱いやすく、`Map<String, dynamic>` に近い表現を保ったまま binary payload を素直に運べます。

## 文書一覧

- [01_adapter_boundary.md](./01_adapter_boundary.md)
  - adapter から読み取れる責務、非責務、thread 不変条件
- [02_vhrp_wire_protocol.md](./02_vhrp_wire_protocol.md)
  - 独自 hosted protocol `VHRP/1` の wire specification
- [03_quarkus_backend_spec.md](./03_quarkus_backend_spec.md)
  - Quarkus 実装を想定した backend の責務分割、API、実装制約
- [04_flutter_adapter_implementation.md](./04_flutter_adapter_implementation.md)
  - Flutter 側 adapter 実装方針、内部コンポーネント、テスト戦略

## 命名

この文書群ではプロトコル名を **VHRP/1** と呼びます。

- 正式名: `VAGINA Hosted Realtime Protocol, version 1`
- WebSocket subprotocol: `vhrp.cbor.v1`

これは本リポジトリ内の adapter / thread model から逆算した命名であり、既存 vendor API の event 名や request 名をそのまま持ち込まない方針です。

## 非目標

- 複数 assistant 音声ストリームの同時多重化
- retention window を超えた任意時点への長期履歴 replay
- 既に流れ終わった assistant PCM を常に sample-accurate に再送すること
- 動画や arbitrary file transfer
- adapter 外から vendor native payload を触ること
