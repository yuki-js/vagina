import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/tools/tools.dart';

/// Self-contained configuration for the voice agent used in a call session.
class VoiceAgentInfo {
  final String id;
  final String name;
  final String description;
  final String? iconEmoji;
  final String voice;
  final String prompt;
  final VoiceAgentApiConfig apiConfig;
  final List<String> enabledTools;
  final SpeedDialReasoningEffort reasoningEffort;
  final bool toolChoiceRequired;

  const VoiceAgentInfo({
    required this.id,
    required this.name,
    required this.description,
    this.iconEmoji,
    required this.voice,
    required this.prompt,
    required this.apiConfig,
    this.enabledTools = const [],
    this.reasoningEffort = SpeedDialReasoningEffort.off,
    this.toolChoiceRequired = false,
  });

  factory VoiceAgentInfo.fromSpeedDial(SpeedDial speedDial) {
    return VoiceAgentInfo(
      id: speedDial.id,
      name: speedDial.name,
      description: speedDial.description ?? '',
      iconEmoji: speedDial.iconEmoji,
      voice: speedDial.voice,
      prompt: speedDial.systemPrompt,
      enabledTools: toolbox.tools
          .map((tool) => tool.definition.toolKey)
          .where((toolKey) => speedDial.enabledTools[toolKey] ?? true)
          .toList(growable: false),
      reasoningEffort: speedDial.reasoningEffort,
      toolChoiceRequired: speedDial.toolChoiceRequired,
      apiConfig: HostedVoiceAgentApiConfig(
        speedDialId: speedDial.id,
        modelId: speedDial.voiceAgentId,
      ),
    );
  }
}
