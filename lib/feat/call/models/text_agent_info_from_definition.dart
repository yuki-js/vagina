import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/models/text_agent_definition.dart';

extension TextAgentInfoFromDefinition on TextAgentDefinition {
  TextAgentInfo toCallTextAgentInfo() {
    return TextAgentInfo(
      id: id,
      name: name,
      description: description ?? '',
      prompt: prompt,
      apiConfig: ServerBackedTextAgentApiConfig(textModelId: textModelId),
      enabledTools: enabledTools,
    );
  }
}
