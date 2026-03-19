# OpenAI Realtime API Tests

このディレクトリには、OpenAI Realtime APIクライアント実装のテストが含まれています。

## テストの種類

### 1. Unit Tests (Fixture-based)

実際のAPIログから記録されたfixtureを使用したunit testです。APIへの接続なしで高速に実行できます。

#### Event Parser Tests
[`realtime_event_parser_test.dart`](realtime_event_parser_test.dart)

- サーバーからのイベント（JSON）を型付きDartオブジェクトにパースする機能をテスト
- text-onlyとaudio-responseの2つのシナリオをカバー
- 各イベントタイプ（session.created、response.text.delta等）の正しいパース処理を検証

```bash
# Event parserのテストを実行
flutter test test/lib/feat/call/services/realtime/oai/realtime_event_parser_test.dart
```

#### Command Encoder Tests
[`realtime_command_encoder_test.dart`](realtime_command_encoder_test.dart)

- クライアントからサーバーへのコマンド（Dartオブジェクト）をJSONにエンコードする機能をテスト
- fixtureとの一致確認、全コマンドタイプのエンコード、immutabilityの検証

```bash
# Command encoderのテストを実行
flutter test test/lib/feat/call/services/realtime/oai/realtime_command_encoder_test.dart
```

### 2. Integration Tests (Live API)

実際のAzure OpenAI Realtime APIエンドポイントに接続してテストします。

#### Realtime Client Integration Tests
[`realtime_client_integration_test.dart`](realtime_client_integration_test.dart)

**事前準備:**
```bash
# API keyファイルを作成
echo "your-azure-openai-api-key" > /tmp/aoai_key.txt
```

**テスト実行:**
```bash
# 全てのintegration testを実行
flutter test test/lib/feat/call/services/realtime/oai/realtime_client_integration_test.dart
```

**テストシナリオ:**
- 接続とsession.createdイベントの受信
- session.updateの送信とsession.updatedの受信
- テキストメッセージの送信とレスポンス受信
- 音声レスポンスモダリティの処理
- 接続エラーのハンドリング

## Fixtureの記録

新しいシナリオのfixtureを記録するには、[`aoai_realtime_fixture_recorder.dart`](../../../../../../../tool/aoai_realtime_fixture_recorder.dart)ツールを使用します。

### 使用方法

```bash
# Text-onlyシナリオを記録
dart run tool/aoai_realtime_fixture_recorder.dart \
  --scenario text-only \
  --output test/fixtures/oai_realtime/text_conversation.json

# Audio-responseシナリオを記録
dart run tool/aoai_realtime_fixture_recorder.dart \
  --scenario audio-response \
  --output test/fixtures/oai_realtime/audio_conversation.json

# Text-with-audioシナリオを記録
dart run tool/aoai_realtime_fixture_recorder.dart \
  --scenario text-with-audio \
  --output test/fixtures/oai_realtime/text_with_audio.json

# Function-callシナリオを記録
dart run tool/aoai_realtime_fixture_recorder.dart \
  --scenario function-call \
  --output test/fixtures/oai_realtime/function_call.json
```

### カスタムシナリオの追加

新しいシナリオを追加するには、[`aoai_realtime_fixture_recorder.dart`](../../../../../../../tool/aoai_realtime_fixture_recorder.dart)の`_executeScenario`関数に新しいケースを追加します：

```dart
Future<void> _runCustomScenario(
  IOWebSocketChannel channel,
  _FixtureRecorder recorder,
) async {
  // セッション設定
  await channel.sink.add(jsonEncode({
    'type': 'session.update',
    'session': { /* your config */ },
  }));
  
  // メッセージ送信など
  // ...
}
```

## Fixture形式

記録されたfixtureは以下のJSON構造を持ちます：

```json
{
  "scenario": "text-only",
  "recorded_at": "2026-03-19T16:37:21.209120",
  "event_count": 20,
  "events": [
    {
      "direction": "sent",
      "timestamp": "2026-03-19T16:37:19.341497",
      "payload": {
        "type": "session.update",
        "session": { /* ... */ }
      }
    },
    {
      "direction": "received",
      "timestamp": "2026-03-19T16:37:18.839195",
      "payload": {
        "type": "session.created",
        "event_id": "event_...",
        "session": { /* ... */ }
      }
    }
  ]
}
```

- **scenario**: シナリオ名
- **recorded_at**: 記録日時
- **event_count**: イベント総数
- **events**: イベントのリスト
  - **direction**: `"sent"`（クライアント→サーバー）または`"received"`（サーバー→クライアント）
  - **timestamp**: イベントのタイムスタンプ
  - **payload**: 実際のJSON payload

## Fixture Loader

[`fixture_loader.dart`](fixture_loader.dart)はfixtureファイルを読み込むためのユーティリティクラスを提供します。

### 使用例

```dart
import 'fixture_loader.dart';

void main() async {
  final loader = RealtimeFixtureLoader(
    'test/fixtures/oai_realtime/text_conversation.json',
  );
  await loader.load();
  
  // 全受信イベント
  final receivedEvents = loader.receivedEvents;
  
  // 全送信イベント
  final sentEvents = loader.sentEvents;
  
  // 特定タイプのイベント
  final sessionCreated = loader.receivedEventsOfType('session.created');
  final sessionUpdates = loader.sentEventsOfType('session.update');
}
```

## CI/CDでの実行

### Unit Tests (常に実行)
```yaml
- name: Run unit tests
  run: |
    flutter test test/lib/feat/call/services/realtime/oai/realtime_event_parser_test.dart
    flutter test test/lib/feat/call/services/realtime/oai/realtime_command_encoder_test.dart
```

### Integration Tests (API keyが利用可能な場合のみ)
```yaml
- name: Run integration tests
  run: |
    if [ -f /tmp/aoai_key.txt ]; then
      flutter test test/lib/feat/call/services/realtime/oai/realtime_client_integration_test.dart
    else
      echo "Skipping integration tests: API key not found"
    fi
```

## トラブルシューティング

### Fixture記録時のタイムアウト

デフォルトのタイムアウトは60秒です。必要に応じて`--timeout-seconds`オプションで調整できます：

```bash
dart run tool/aoai_realtime_fixture_recorder.dart \
  --scenario audio-response \
  --timeout-seconds 90 \
  --output test/fixtures/oai_realtime/audio_conversation.json
```

### API keyエラー

```bash
# API keyファイルが存在するか確認
ls -la /tmp/aoai_key.txt

# API keyが空でないか確認
cat /tmp/aoai_key.txt
```

### パーサーエラー

新しいイベントタイプがAPIに追加された場合、[`realtime_event_parser.dart`](../../../../../../lib/feat/call/services/realtime/oai/realtime_event_parser.dart)の`parse`メソッドに新しいケースを追加する必要があります。

## 参考資料

- [OpenAI Realtime API Documentation](/tmp/openai-realtime-index.md)
- [Azure OpenAI Realtime API](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-api)
