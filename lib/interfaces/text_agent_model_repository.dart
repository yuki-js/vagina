import 'package:vagina/models/text_agent_model_preset.dart';

abstract class TextAgentModelRepository {
  Future<List<TextAgentModelPreset>> listTextAgentModels();
}
