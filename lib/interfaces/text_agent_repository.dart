import 'package:vagina/models/text_agent_definition.dart';

abstract class TextAgentRepository {
  Future<TextAgentDefinition> create({
    required String name,
    required String prompt,
    String? description,
    String textModelId = TextAgentDefinition.defaultTextModelId,
    Map<String, bool> enabledTools = const {},
  });

  Future<List<TextAgentDefinition>> getAll();

  Future<TextAgentDefinition?> getById(String id);

  Future<bool> update(TextAgentDefinition textAgent);

  Future<bool> delete(String id);
}
