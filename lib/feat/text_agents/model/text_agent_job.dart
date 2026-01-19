/// Expected latency tier for text agent queries
enum TextAgentExpectLatency {
  instant('instant'),
  long('long'),
  ultraLong('ultra_long');

  final String value;
  const TextAgentExpectLatency(this.value);

  factory TextAgentExpectLatency.fromString(String value) {
    return TextAgentExpectLatency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TextAgentExpectLatency.instant,
    );
  }
}

/// Status of a text agent job
enum TextAgentJobStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  failed('failed'),
  expired('expired');

  final String value;
  const TextAgentJobStatus(this.value);

  factory TextAgentJobStatus.fromString(String value) {
    return TextAgentJobStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TextAgentJobStatus.pending,
    );
  }
}

/// Represents an async text agent job
class TextAgentJob {
  final String id; // This is the token
  final String agentId;
  final String prompt;
  final TextAgentExpectLatency expectLatency;
  final TextAgentJobStatus status;
  final String? result;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime expiresAt;

  const TextAgentJob({
    required this.id,
    required this.agentId,
    required this.prompt,
    required this.expectLatency,
    required this.status,
    this.result,
    this.error,
    required this.createdAt,
    this.completedAt,
    required this.expiresAt,
  });

  TextAgentJob copyWith({
    String? id,
    String? agentId,
    String? prompt,
    TextAgentExpectLatency? expectLatency,
    TextAgentJobStatus? status,
    String? result,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? expiresAt,
  }) {
    return TextAgentJob(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      prompt: prompt ?? this.prompt,
      expectLatency: expectLatency ?? this.expectLatency,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'prompt': prompt,
      'expectLatency': expectLatency.value,
      'status': status.value,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      'createdAt': createdAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory TextAgentJob.fromJson(Map<String, dynamic> json) {
    return TextAgentJob(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      prompt: json['prompt'] as String,
      expectLatency: TextAgentExpectLatency.fromString(
        json['expectLatency'] as String,
      ),
      status: TextAgentJobStatus.fromString(json['status'] as String),
      result: json['result'] as String?,
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
