import 'package:vagina/models/skill.dart';

/// スキルデータを管理するリポジトリ
abstract class SkillRepository {
  /// スキルを保存する
  Future<void> save(Skill skill);

  /// すべてのスキルを取得する
  Future<List<Skill>> getAll();

  /// IDでスキルを取得する
  Future<Skill?> getById(String id);

  /// スキルを更新する
  Future<bool> update(Skill skill);

  /// スキルを削除する
  Future<bool> delete(String id);
}
