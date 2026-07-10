import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

part 'text_agent_providers.g.dart';

@riverpod
Future<List<TextAgentDefinition>> textAgents(Ref ref) {
  return AppContainer.textAgents.getAll();
}

@riverpod
Future<List<TextAgentModelPreset>> textAgentModels(Ref ref) {
  return AppContainer.textAgentModels.listTextAgentModels();
}
