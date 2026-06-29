import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

final textAgentsProvider = FutureProvider<List<TextAgentDefinition>>((
  ref,
) async {
  final repo = AppContainer.textAgents;
  return repo.getAll();
});

final textAgentModelsProvider = FutureProvider<List<TextAgentModelPreset>>((
  ref,
) async {
  final repo = AppContainer.textAgentModels;
  return repo.listTextAgentModels();
});
