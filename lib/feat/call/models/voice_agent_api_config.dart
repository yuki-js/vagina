/// API access selection for a voice agent available during a call session.
abstract class VoiceAgentApiConfig {
  static const String hostedType = 'hosted';

  const VoiceAgentApiConfig();

  Map<String, dynamic> toJson();

  factory VoiceAgentApiConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      VoiceAgentApiConfig.hostedType => HostedVoiceAgentApiConfig.fromJson(
        json,
      ),
      _ => throw ArgumentError('Unknown VoiceAgentApiConfig type: $type'),
    };
  }
}

/// Use the application's hosted realtime voice API.
class HostedVoiceAgentApiConfig extends VoiceAgentApiConfig {
  final String speedDialId;
  final String modelId;

  const HostedVoiceAgentApiConfig({
    required this.speedDialId,
    this.modelId = '',
  });

  HostedVoiceAgentApiConfig copyWith({String? speedDialId, String? modelId}) {
    return HostedVoiceAgentApiConfig(
      speedDialId: speedDialId ?? this.speedDialId,
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': VoiceAgentApiConfig.hostedType,
      'speedDialId': speedDialId,
      if (modelId.isNotEmpty) 'modelId': modelId,
    };
  }

  factory HostedVoiceAgentApiConfig.fromJson(Map<String, dynamic> json) {
    return HostedVoiceAgentApiConfig(
      speedDialId:
          json['speedDialId'] as String? ?? json['modelId'] as String? ?? '',
      modelId: json['modelId'] as String? ?? '',
    );
  }
}
