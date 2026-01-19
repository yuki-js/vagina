/// Azure OpenAI configuration for a text agent
class AzureTextAgentConfig {
  final String endpoint;
  final String apiKey;
  final String apiVersion;
  final String deploymentName;
  final String? modelName;
  final int? maxTokens;
  final double? temperature;

  const AzureTextAgentConfig({
    required this.endpoint,
    required this.apiKey,
    this.apiVersion = '2024-10-01-preview',
    required this.deploymentName,
    this.modelName,
    this.maxTokens = 4096,
    this.temperature = 1.0,
  });

  AzureTextAgentConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? apiVersion,
    String? deploymentName,
    String? modelName,
    int? maxTokens,
    double? temperature,
  }) {
    return AzureTextAgentConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      apiVersion: apiVersion ?? this.apiVersion,
      deploymentName: deploymentName ?? this.deploymentName,
      modelName: modelName ?? this.modelName,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'apiKey': apiKey,
      'apiVersion': apiVersion,
      'deploymentName': deploymentName,
      if (modelName != null) 'modelName': modelName,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
    };
  }

  factory AzureTextAgentConfig.fromJson(Map<String, dynamic> json) {
    return AzureTextAgentConfig(
      endpoint: json['endpoint'] as String,
      apiKey: json['apiKey'] as String,
      apiVersion: json['apiVersion'] as String? ?? '2024-10-01-preview',
      deploymentName: json['deploymentName'] as String,
      modelName: json['modelName'] as String?,
      maxTokens: json['maxTokens'] as int? ?? 4096,
      temperature: json['temperature'] as double? ?? 1.0,
    );
  }
}
