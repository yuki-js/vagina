import 'package:vagina/models/skill.dart';
import 'package:vagina/interfaces/skill_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';

/// JSON-based implementation of SkillRepository
class JsonSkillRepository implements SkillRepository {
  static const _tag = 'SkillRepo';
  static const _skillsKey = 'skills';

  final KeyValueStore _store;
  final LogService _logService;

  JsonSkillRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> save(Skill skill) async {
    _logService.debug(_tag, 'Saving skill: ${skill.id}');

    final skills = await getAll();
    skills.add(skill);

    final skillsJson = skills.map((s) => s.toJson()).toList();
    await _store.set(_skillsKey, skillsJson);

    _logService.info(_tag, 'Skill saved: ${skill.id}');
  }

  @override
  Future<List<Skill>> getAll() async {
    final data = await _store.get(_skillsKey);

    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logService.warn(_tag, 'Invalid skills data type');
      }
      return [];
    }

    return data
        .map((json) => Skill.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Skill?> getById(String id) async {
    final skills = await getAll();
    try {
      return skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> update(Skill skill) async {
    _logService.debug(_tag, 'Updating skill: ${skill.id}');

    final skills = await getAll();
    final index = skills.indexWhere((s) => s.id == skill.id);

    if (index == -1) {
      _logService.warn(_tag, 'Skill not found for update: ${skill.id}');
      return false;
    }

    skills[index] = skill;

    final skillsJson = skills.map((s) => s.toJson()).toList();
    await _store.set(_skillsKey, skillsJson);

    _logService.info(_tag, 'Skill updated: ${skill.id}');
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    _logService.debug(_tag, 'Deleting skill: $id');

    final skills = await getAll();
    final initialLength = skills.length;
    skills.removeWhere((s) => s.id == id);

    if (skills.length == initialLength) {
      _logService.warn(_tag, 'Skill not found: $id');
      return false;
    }

    final skillsJson = skills.map((s) => s.toJson()).toList();
    await _store.set(_skillsKey, skillsJson);

    _logService.info(_tag, 'Skill deleted: $id');
    return true;
  }
}
