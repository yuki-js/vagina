import 'package:vagina/api/generated/api_models.dart' as api_models;

enum TextAgentQueryStatus { completed, requiresTool, failed }

final class TextAgentQueryResponse {
  final TextAgentQueryStatus status;
  final String? text;
  final List<TextAgentToolCallRequest> toolCalls;
  final String? errorCode;
  final String? errorMessage;

  const TextAgentQueryResponse({
    required this.status,
    this.text,
    this.toolCalls = const <TextAgentToolCallRequest>[],
    this.errorCode,
    this.errorMessage,
  });

  factory TextAgentQueryResponse.fromGenerated(
    api_models.QueryTextAgentSuccessBody body,
  ) {
    final status = switch (body.status) {
      api_models.QueryTextAgentSuccessBodyStatus.completed =>
        TextAgentQueryStatus.completed,
      api_models.QueryTextAgentSuccessBodyStatus.requiresTool =>
        TextAgentQueryStatus.requiresTool,
      api_models.QueryTextAgentSuccessBodyStatus.failed =>
        TextAgentQueryStatus.failed,
    };

    return TextAgentQueryResponse(
      status: status,
      text: body.text?.isNotEmpty == true ? body.text : null,
      toolCalls:
          body.toolCalls
              ?.map(TextAgentToolCallRequest.fromGenerated)
              .toList(growable: false) ??
          const <TextAgentToolCallRequest>[],
      errorCode: body.error?.code,
      errorMessage: body.error?.message,
    );
  }
}

final class TextAgentToolCallRequest {
  final String id;
  final String name;
  final String arguments;

  const TextAgentToolCallRequest({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory TextAgentToolCallRequest.fromGenerated(
    api_models.TextAgentToolCall toolCall,
  ) {
    if (toolCall.id.isEmpty) {
      throw FormatException('Text agent tool call is missing a valid id.');
    }
    if (toolCall.name.isEmpty) {
      throw FormatException('Text agent tool call is missing a valid name.');
    }
    if (toolCall.arguments.isEmpty) {
      throw FormatException(
        'Text agent tool call is missing valid JSON arguments.',
      );
    }

    return TextAgentToolCallRequest(
      id: toolCall.id,
      name: toolCall.name,
      arguments: toolCall.arguments,
    );
  }
}

final class TextAgentToolResultSubmission {
  final String toolCallId;
  final String output;
  final bool isError;

  const TextAgentToolResultSubmission({
    required this.toolCallId,
    required this.output,
    required this.isError,
  });

  api_models.QueryTextAgentBodyToolResult toGenerated() {
    return api_models.QueryTextAgentBodyToolResult(
      toolCallId: toolCallId,
      output: output,
      isError: isError,
    );
  }
}
