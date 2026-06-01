/// API access selection for a voice agent available during a call session.
abstract class VoiceAgentApiConfig {
  static const String hostedType = 'hosted';
  static const String selfhostedType = 'selfhosted';

  const VoiceAgentApiConfig();

  Map<String, dynamic> toJson();

  factory VoiceAgentApiConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      VoiceAgentApiConfig.hostedType =>
        HostedVoiceAgentApiConfig.fromJson(json),
      VoiceAgentApiConfig.selfhostedType =>
        SelfhostedVoiceAgentApiConfig.fromJson(json),
      _ => throw ArgumentError('Unknown VoiceAgentApiConfig type: $type'),
    };
  }
}

/// Provider selection for self-hosted voice agent APIs.
enum VoiceAgentProviderType {
  openai,
  gemini,
  openaiCc,
}

/// Use the application's hosted realtime voice API.
class HostedVoiceAgentApiConfig extends VoiceAgentApiConfig {
  final String modelId;

  const HostedVoiceAgentApiConfig({
    required this.modelId,
  });

  HostedVoiceAgentApiConfig copyWith({
    String? modelId,
  }) {
    return HostedVoiceAgentApiConfig(
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': VoiceAgentApiConfig.hostedType,
      'modelId': modelId,
    };
  }

  factory HostedVoiceAgentApiConfig.fromJson(Map<String, dynamic> json) {
    return HostedVoiceAgentApiConfig(
      modelId: json['modelId'] as String? ?? '',
    );
  }
}

/// Use a self-hosted or user-managed realtime voice API endpoint.
class SelfhostedVoiceAgentApiConfig extends VoiceAgentApiConfig {
  final VoiceAgentProviderType providerType;
  final String baseUrl;
  final String apiKey;
  final String? transcriptionModel;
  final Map<String, Object?> params;

  const SelfhostedVoiceAgentApiConfig({
    required this.providerType,
    required this.baseUrl,
    required this.apiKey,
    this.transcriptionModel,
    this.params = const {},
  });

  SelfhostedVoiceAgentApiConfig copyWith({
    VoiceAgentProviderType? providerType,
    String? baseUrl,
    String? apiKey,
    String? transcriptionModel,
    bool clearTranscriptionModel = false,
    Map<String, Object?>? params,
  }) {
    return SelfhostedVoiceAgentApiConfig(
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      transcriptionModel: clearTranscriptionModel
          ? null
          : (transcriptionModel ?? this.transcriptionModel),
      params: params ?? this.params,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': VoiceAgentApiConfig.selfhostedType,
      'providerType': providerType.name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      if (transcriptionModel != null) 'transcriptionModel': transcriptionModel,
      'params': params,
    };
  }

  factory SelfhostedVoiceAgentApiConfig.fromJson(Map<String, dynamic> json) {
    final providerName = json['providerType'] as String?;
    return SelfhostedVoiceAgentApiConfig(
      providerType: VoiceAgentProviderType.values.firstWhere(
        (value) => value.name == providerName,
        orElse: () => VoiceAgentProviderType.openai,
      ),
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      transcriptionModel: json['transcriptionModel'] as String?,
      params: json['params'] is Map
          ? Map<String, Object?>.from(json['params'] as Map)
          : const <String, Object?>{},
    );
  }
}
