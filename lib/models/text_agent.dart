import 'package:flutter/foundation.dart';

/// Represents a text agent that can be used for advanced reasoning
@immutable
class TextAgent {
  final String id;
  final String name;
  final String description;
  final String modelIdentifier;
  final List<String> capabilities;
  final bool isAvailable;
  
  const TextAgent({
    required this.id,
    required this.name,
    required this.description,
    required this.modelIdentifier,
    this.capabilities = const [],
    this.isAvailable = true,
  });

  TextAgent copyWith({
    String? id,
    String? name,
    String? description,
    String? modelIdentifier,
    List<String>? capabilities,
    bool? isAvailable,
  }) {
    return TextAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      modelIdentifier: modelIdentifier ?? this.modelIdentifier,
      capabilities: capabilities ?? this.capabilities,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'modelIdentifier': modelIdentifier,
      'capabilities': capabilities,
      'isAvailable': isAvailable,
    };
  }

  factory TextAgent.fromJson(Map<String, dynamic> json) {
    return TextAgent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      modelIdentifier: json['modelIdentifier'] as String,
      capabilities: (json['capabilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextAgent &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.modelIdentifier == modelIdentifier &&
        listEquals(other.capabilities, capabilities) &&
        other.isAvailable == isAvailable;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      modelIdentifier,
      Object.hashAll(capabilities),
      isAvailable,
    );
  }
}

/// Expected latency for text agent query
enum AgentLatency {
  /// Instant response (< 1s)
  instant('instant'),
  
  /// Long response (1-10s)
  long('long'),
  
  /// Ultra long response (> 10s)
  ultraLong('ultra_long');

  final String value;
  const AgentLatency(this.value);

  static AgentLatency fromString(String value) {
    return AgentLatency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AgentLatency.instant,
    );
  }
}

/// Response from text agent query
@immutable
class TextAgentResponse {
  final String content;
  final String? requestId;
  final bool isComplete;
  final DateTime timestamp;
  
  TextAgentResponse({
    required this.content,
    this.requestId,
    this.isComplete = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TextAgentResponse copyWith({
    String? content,
    String? requestId,
    bool? isComplete,
    DateTime? timestamp,
  }) {
    return TextAgentResponse(
      content: content ?? this.content,
      requestId: requestId ?? this.requestId,
      isComplete: isComplete ?? this.isComplete,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'requestId': requestId,
      'isComplete': isComplete,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TextAgentResponse.fromJson(Map<String, dynamic> json) {
    return TextAgentResponse(
      content: json['content'] as String,
      requestId: json['requestId'] as String?,
      isComplete: json['isComplete'] as bool? ?? true,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// Context for call end
@immutable
class CallEndContext {
  final String? reason;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;
  
  CallEndContext({
    this.reason,
    this.additionalData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'additionalData': additionalData,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CallEndContext.fromJson(Map<String, dynamic> json) {
    return CallEndContext(
      reason: json['reason'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
