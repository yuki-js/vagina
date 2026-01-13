# Character Non-nullable化タスク - Issue #89

## 概要
キャラクターの「デフォルト」特例扱いを廃止し、Non-nullableな実体として統一化する。

## 背景
現在、スピードダイヤル等の設定において、キャラクターは「設定あり」と「設定なし（デフォルト）」で扱いが分かれており、
呼び出しロジックが「デフォルト」か「カスタム」かで分岐している。

## 目標
- キャラクター設定を必須（Non-nullable）にする
- システム内に必ず1つ以上のキャラクターが存在する状態を保証する
- 初期状態として「Default」という名前のキャラクターインスタンスを用意する

## 変更内容

### 1. データ構造の変更

#### Character モデルの更新
- `lib/models/character.dart` を確認し、必要に応じて更新

#### Repository層の更新
- `lib/repositories/character_repository.dart`
  - 初期化時に「Default」キャラクターを自動作成
  - 削除時に「Default」キャラクターは削除不可とする
  - リネーム時に「Default」キャラクターは名前変更不可とする

### 2. 「Default」キャラクターの仕様

#### 制約
- **削除不可**: ユーザーはこのキャラクターを削除できない
- **リネーム不可**: 「Default」という名前の変更も禁止
- **編集可**: その他のパラメータ（設定・プロンプト等）は編集可能

#### 初期化処理
```dart
// 例: RepositoryFactory.initialize() または各リポジトリの初期化時
Future<void> ensureDefaultCharacterExists() async {
  final characters = await characterRepository.getAll();
  if (characters.isEmpty) {
    // Default キャラクターを作成
    final defaultCharacter = Character(
      id: 'default',  // 固定ID
      name: 'Default',
      systemPrompt: '...',  // デフォルトプロンプト
      voice: 'default_voice',
      // その他のパラメータ
    );
    await characterRepository.create(defaultCharacter);
  }
}
```

### 3. SpeedDial モデルの更新

#### 現状
```dart
class SpeedDial {
  final String? characterId;  // nullable
  // ...
}
```

#### 変更後
```dart
class SpeedDial {
  final String characterId;  // Non-nullable、デフォルトは'default'
  // ...
}
```

#### マイグレーション
既存のスピードダイヤルで`characterId`が`null`の場合、`'default'`に設定する。

### 4. 通話・スピードダイヤルの挙動

#### スピードダイヤル以外からの発信
```dart
// Before
final characterId = speedDial?.characterId ?? null;  // nullの場合デフォルト扱い

// After
final characterId = 'default';  // 常に「Default」キャラクターを使用
```

#### スピードダイヤルからの発信
```dart
// Before
final characterId = speedDial.characterId ?? 'default';  // nullチェック

// After
final characterId = speedDial.characterId;  // Non-nullableなのでそのまま使用
```

## 作業手順

### Phase 1: データモデルとリポジトリの更新
1. `Character`モデルの確認・更新
2. `CharacterRepository`に削除・リネーム制約を追加
3. 初期化時に「Default」キャラクター作成処理を追加
4. テスト作成・実行

### Phase 2: SpeedDialモデルの更新
1. `SpeedDial`モデルで`characterId`をNon-nullableに変更
2. データマイグレーション処理を実装
3. 既存データの移行テスト

### Phase 3: UIの更新
1. キャラクター削除UIで「Default」は削除不可にする
2. キャラクター編集UIで「Default」の名前変更を禁止する
3. スピードダイヤル作成時のデフォルト値を「Default」に設定

### Phase 4: ビジネスロジックの更新
1. 通話開始ロジックの条件分岐を削除
2. `null`チェックを削除し、常にキャラクターIDを使用するよう統一

### Phase 5: テストと検証
1. ユニットテスト実行
2. E2Eテスト（可能であれば）
3. 各プラットフォームでビルド・動作確認

## 影響範囲の特定

### 検索コマンド
```bash
# characterId が null チェックされている箇所
grep -r "characterId.*??" lib/ --include="*.dart"
grep -r "characterId.*null" lib/ --include="*.dart"

# Character型がnullableとして扱われている箇所
grep -r "Character?" lib/ --include="*.dart"

# スピードダイヤルのキャラクター参照
grep -r "speedDial.*character" lib/ --include="*.dart"
```

## 注意事項
- この変更はデータ構造の根本的な変更を伴うため、段階的に進める
- 既存データの移行処理が必要
- リリース前に十分なテストを実施する
- 可能であれば、フィーチャーフラグを使用して段階的にロールアウト

## 完了条件
- [ ] 「Default」キャラクターが自動作成される
- [ ] 「Default」キャラクターは削除不可
- [ ] 「Default」キャラクターは名前変更不可
- [ ] SpeedDialのcharacterIdがNon-nullable
- [ ] 既存データが適切に移行される
- [ ] すべてのnullチェックが削除される
- [ ] テストがすべてパスする
- [ ] 各プラットフォームでビルドが成功する
- [ ] 実機での動作確認が完了する
