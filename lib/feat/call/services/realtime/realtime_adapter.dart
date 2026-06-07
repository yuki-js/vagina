import 'dart:typed_data';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

enum RealtimeAudioTurnMode { voiceActivity, manual }

/// Provider-agnostic realtime voice adapter.
///
/// Design principles:
/// - Callers never touch provider-native payloads (no `Map<String, dynamic>`
///   session patches, no `response.create`, no `output_audio_buffer.clear`).
/// - Live microphone streaming and client-managed audio turns are separate
///   concerns.
/// - Client-side/manual turn capture happens above the adapter; provider-native
///   audio ingestion/encoding stays inside the adapter.
/// - Each `send*` method implies "and generate a response".  The adapter
///   decides how to trigger that for its protocol.
/// - Provider-specific session defaults (audio format, VAD config, transcription
///   model) live inside the adapter, not here.
abstract interface class RealtimeAdapter {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The accumulated conversation thread. Semi-mutable for delta efficiency.
  RealtimeThread get thread;

  /// Fires whenever [thread] is mutated (new item, delta, status change…).
  Stream<RealtimeThread> get threadUpdates;

  /// Current connection lifecycle state.
  RealtimeAdapterConnectionState get connectionState;
  /// Connection lifecycle state changes.
  Stream<RealtimeAdapterConnectionState> get connectionStateUpdates;

  /// Protocol and transport errors.
  Stream<RealtimeAdapterError> get errors;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Open a connection.
  ///
  /// [apiConfig] carries credentials and provider routing.
  /// [voice] and [instructions] are the only session-level knobs the caller
  /// needs; everything else (audio format, VAD, transcription model) is owned
  /// by the adapter's defaults.
  Future<void> connect(
    VoiceAgentApiConfig apiConfig, {
    String? voice,
    String? instructions,
  });

  /// Gracefully close the connection and release all resources. Idempotent.
  Future<void> dispose();

  // ---------------------------------------------------------------------------
  // Audio input / output
  // ---------------------------------------------------------------------------

  /// Bind live PCM audio from [audioStream] for turn modes that use streaming
  /// microphone input.
  ///
  /// In [RealtimeAudioTurnMode.voiceActivity], implementations may forward or
  /// buffer chunks according to provider protocol. In
  /// [RealtimeAudioTurnMode.manual], callers typically accumulate a client-side
  /// turn and submit it with [sendAudioOneShot].
  /// Passing `null` unbinds the currently bound live audio input stream.
  /// Calling this while a stream is already bound replaces the previous one.
  Future<void> bindAudioInput(Stream<Uint8List>? audioStream);

  /// Switch between server-side VAD turn handling and client-managed one-shot
  /// audio turns. This is orthogonal to whether live input is currently bound.
  Future<void> setAudioTurnMode(RealtimeAudioTurnMode mode);

  /// Provider-decoded assistant PCM output stream.
  ///
  /// Consumers can pipe this directly into playback services without decoding
  /// provider-native payloads themselves.
  Stream<Uint8List> get assistantAudioStream;

  /// Fires when the current assistant audio response has no more PCM chunks.
  ///
  /// This is separate from [assistantAudioStream] so playback can distinguish
  /// chunk delivery from response-boundary completion.
  Stream<void> get assistantAudioCompleted;

  /// Whether VAD currently considers the user to be speaking.
  bool get isUserSpeaking;

  /// Emits the current VAD speaking state whenever it changes.
  Stream<bool> get isUserSpeakingUpdates;

  // ---------------------------------------------------------------------------
  // Tool configuration
  // ---------------------------------------------------------------------------

  /// Register the tools available to the model for the current session.
  ///
  /// Implementations should translate [tools] into the provider-native session
  /// configuration format. Calling this with an empty list disables tool
  /// calling for the session.
  Future<void> registerTools(List<ToolDefinition> tools);

  /// Apply an opaque provider-extension update.
  ///
  /// [extensionType] and [payload] are application-defined values. Adapters may
  /// ignore unsupported extensions by returning `false`.
  Future<bool> applyProviderExtension(
    String extensionType,
    Map<String, dynamic> payload,
  );

  // ---------------------------------------------------------------------------
  // User content  (each call implies "and generate a response")
  // ---------------------------------------------------------------------------

  /// Send one completed audio turn from the user. Returns the local item ID.
  ///
  /// The caller owns client-side/manual turn capture and passes the final PCM
  /// payload here. Implementations translate [audioBytes] into the provider-native
  /// input format and generate a response.
  Future<String> sendAudioOneShot(Uint8List audioBytes);

  /// Send a text message from the user. Returns the local item ID.
  Future<String> sendText(String text);

  /// Send an image from the user. Returns the local item ID.
  Future<String> sendImage(Uint8List imageBytes);

  /// Return the result of a function/tool call the model requested.
  /// [callId] is the provider-assigned correlation ID from the thread item.
  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  });

  /// Mark pending/running function calls as locally cancelled.
  ///
  /// This is used when the current assistant turn is interrupted so stale tool
  /// work no longer appears executable in the projected thread state.
  void cancelFunctionCalls({
    Set<String> itemIds = const <String>{},
    Set<String> callIds = const <String>{},
  });

  // ---------------------------------------------------------------------------
  // Response control
  // ---------------------------------------------------------------------------

  /// Interrupt the model's current response (cancel generation + clear any
  /// buffered output audio).
  Future<void> interrupt();
}
