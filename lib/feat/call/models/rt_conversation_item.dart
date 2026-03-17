/// Role of the actor associated with a realtime conversation item.
enum RtConversationItemRole {
  user,
  assistant,
  system,
  tool,
}

/// Provider-agnostic kind of realtime conversation item.
///
/// This intentionally includes more than just user/assistant/system messages.
enum RtConversationItemKind {
  message,
  functionCall,
  functionCallOutput,
}

/// Lightweight lifecycle status attached to a realtime conversation item.
enum RtConversationItemStatus {
  inProgress,
  incomplete,
  completed,
}

/// Base type for a single item in a realtime conversation thread.
abstract class RtConversationItem {
  final String? id;
  final RtConversationItemKind kind;
  final RtConversationItemStatus? status;

  const RtConversationItem({
    required this.id,
    required this.kind,
    this.status,
  });
}

/// Base type for message-shaped conversation items.
abstract class RtMessageConversationItem extends RtConversationItem {
  final RtConversationItemRole role;
  final List<RtMessageContentPart> content;

  const RtMessageConversationItem({
    required super.id,
    required this.role,
    required this.content,
    super.status,
  }) : super(kind: RtConversationItemKind.message);
}

/// A system-authored message item.
class RtSystemMessageItem extends RtMessageConversationItem {
  const RtSystemMessageItem({
    required super.id,
    required super.content,
    super.status,
  }) : super(role: RtConversationItemRole.system);
}

/// A user-authored message item.
class RtUserMessageItem extends RtMessageConversationItem {
  const RtUserMessageItem({
    required super.id,
    required super.content,
    super.status,
  }) : super(role: RtConversationItemRole.user);
}

/// An assistant-authored message item.
class RtAssistantMessageItem extends RtMessageConversationItem {
  const RtAssistantMessageItem({
    required super.id,
    required super.content,
    super.status,
  }) : super(role: RtConversationItemRole.assistant);
}

/// A model-initiated function call item.
class RtFunctionCallItem extends RtConversationItem {
  final String name;
  final String arguments;
  final String? callId;

  const RtFunctionCallItem({
    required super.id,
    required this.name,
    required this.arguments,
    this.callId,
    super.status,
  }) : super(kind: RtConversationItemKind.functionCall);
}

/// The output associated with a prior function call item.
class RtFunctionCallOutputItem extends RtConversationItem {
  final String callId;
  final String output;

  const RtFunctionCallOutputItem({
    required super.id,
    required this.callId,
    required this.output,
    super.status,
  }) : super(kind: RtConversationItemKind.functionCallOutput);
}

/// Base type for message content parts held by message items.
abstract class RtMessageContentPart {
  const RtMessageContentPart();
}

/// Text input content used by system or user messages.
class RtInputTextPart extends RtMessageContentPart {
  final String text;

  const RtInputTextPart({
    required this.text,
  });
}

/// Audio input content used by user messages.
class RtInputAudioPart extends RtMessageContentPart {
  // Raw audio is intentionally not persisted in the conversation item model.
  // final String? audio;
  final String? transcript;

  const RtInputAudioPart({
    // this.audio,
    this.transcript,
  });
}

/// Image input content used by user messages.
class RtInputImagePart extends RtMessageContentPart {
  final String imageUrl;
  final RtImageDetail detail;

  const RtInputImagePart({
    required this.imageUrl,
    this.detail = RtImageDetail.auto,
  });
}

/// Text output content used by assistant messages.
class RtOutputTextPart extends RtMessageContentPart {
  final String text;

  const RtOutputTextPart({
    required this.text,
  });
}

/// Audio output content used by assistant messages.
class RtOutputAudioPart extends RtMessageContentPart {
  // Raw audio is intentionally not persisted in the conversation item model.
  // final String? audio;
  final String? transcript;

  const RtOutputAudioPart({
    // this.audio,
    this.transcript,
  });
}

/// Detail hint associated with input images.
enum RtImageDetail {
  auto,
  low,
  high,
}
