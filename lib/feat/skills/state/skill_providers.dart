/// スキル機能の Riverpod プロバイダ
///
/// `skillsProvider` と `skillRepositoryProvider` の実体は
/// `repository_providers.dart` で一元管理し、ここでは再エクスポートのみ行う。
/// これによりスキル機能内のコードが `repository_providers.dart` に直接依存せず、
/// 将来の内部実装変更が容易になる。
library;

export 'package:vagina/core/state/repository_providers.dart';
