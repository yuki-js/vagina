import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'oai_cc_client.dart';
import 'oai_cc_connect_config.dart';
import 'oai_cc_event.dart';
import 'oai_cc_request.dart';
import 'oai_cc_wav_encoder.dart';

/// OpenAI Chat Completions API implementation of [RealtimeAdapter].
///
/// Live microphone input is lifecycle-bound only; completed manual/PTT audio
/// turns are supplied by CallService through [sendAudioOneShot].
final class OaiCcRealtimeAdapter implements RealtimeAdapter {
  /// Test Chat Completions API connectivity.
  static Future<void> testConnection(
    String baseUrl,
    String apiKey, {
    VoiceAgentModality modality = VoiceAgentModality.audio,
  }) async {
    final parsedUri = Uri.parse(baseUrl);
    if (parsedUri.scheme.isEmpty || parsedUri.host.isEmpty) {
      throw Exception('Invalid Chat Completions base URI');
    }

    String extractedModel = 'gpt-4o';
    Uri cleanUri = parsedUri;

    if (parsedUri.queryParameters.containsKey('model')) {
      final modelFromQuery = parsedUri.queryParameters['model'];
      if (modelFromQuery != null && modelFromQuery.isNotEmpty) {
        extractedModel = modelFromQuery;
      }
      final newQueryParameters =
          Map<String, String>.from(parsedUri.queryParameters)..remove('model');
      cleanUri = parsedUri.replace(
        queryParameters: newQueryParameters.isEmpty ? null : newQueryParameters,
      );
    }

    final isAudioModel = modality == VoiceAgentModality.audio;

    final config = OaiCcConnectConfig(
      baseUrl: cleanUri,
      model: extractedModel,
      apiKey: apiKey,
      modality: modality,
    );

    final request = OaiCcRequest(
      model: extractedModel,
      messages: [
        const OaiCcTextMessage(role: 'user', content: 'ping'),
      ],
      stream: true,
      modalities: isAudioModel ? ['text', 'audio'] : null,
      additionalParams: isAudioModel
          ? {
              'audio': {
                'voice': 'alloy',
                'format': 'pcm16',
              }
            }
          : null,
    );

    final client = OaiCcClient();
    final completer = Completer<void>();
    StreamSubscription<OaiCcEvent>? sub;

    try {
      final eventStream = client.streamCompletions(
        config: config,
        requestPayload: request,
      );

      sub = eventStream.listen(
        (event) {
          if (event is OaiCcErrorEvent) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(event.message));
            }
          } else {
            // If we receive any successful delta/finished event, connection is verified.
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(err.toString()));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );
    } finally {
      await sub?.cancel();
      client.dispose();
    }
  }

  final OaiCcClient _client;
  final RealtimeThread _thread;

  final StreamController<RealtimeThread> _threadController =
      StreamController<RealtimeThread>.broadcast();
  final StreamController<RealtimeAdapterConnectionState> _connectionController =
      StreamController<RealtimeAdapterConnectionState>.broadcast();
  final StreamController<RealtimeAdapterError> _errorController =
      StreamController<RealtimeAdapterError>.broadcast();
  final StreamController<Uint8List> _assistantAudioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<void> _assistantAudioCompletedController =
      StreamController<void>.broadcast();
  final StreamController<bool> _userSpeakingStateController =
      StreamController<bool>.broadcast();

  StreamSubscription<Uint8List>? _audioInputSubscription;
  StreamSubscription<OaiCcEvent>? _responseStreamSubscription;

  OaiCcConnectConfig? _config;
  String _instructions = '';
  String? _voice;
  RealtimeAdapterConnectionState _connectionState =
      const RealtimeAdapterConnectionState.idle();
  int _localIdCounter = 0;
  bool _disposed = false;
  final Map<String, String> _assistantAudioIds = {};
  final Map<String, String> _toolCallIdToItemId = {};
  final Map<int, String> _activeToolCallIndexToItemId = {};
  List<ToolDefinition> _tools = const <ToolDefinition>[];

  OaiCcRealtimeAdapter({
    OaiCcClient? client,
    String? threadId,
  })  : _client = client ?? OaiCcClient(),
        _thread = RealtimeThread(
            id: threadId ??
                'thread_cc_${DateTime.now().millisecondsSinceEpoch}');

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  @override
  RealtimeThread get thread => _thread;

  @override
  Stream<RealtimeThread> get threadUpdates => _threadController.stream;

  @override
  RealtimeAdapterConnectionState get connectionState => _connectionState;

  @override
  Stream<RealtimeAdapterConnectionState> get connectionStateUpdates =>
      _connectionController.stream;

  @override
  Stream<RealtimeAdapterError> get errors => _errorController.stream;

  @override
  Stream<Uint8List> get assistantAudioStream =>
      _assistantAudioController.stream;

  @override
  Stream<void> get assistantAudioCompleted =>
      _assistantAudioCompletedController.stream;

  @override
  Stream<bool> get isUserSpeakingUpdates => _userSpeakingStateController.stream;

  @override
  bool get isUserSpeaking => false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(
    VoiceAgentApiConfig apiConfig, {
    String? voice,
  }) async {
    _ensureNotDisposed();
    _setConnectionState(const RealtimeAdapterConnectionState.connecting());

    if (apiConfig is! SelfhostedVoiceAgentApiConfig) {
      final state = RealtimeAdapterConnectionState.failed(
        message:
            'OaiCcRealtimeAdapter only supports SelfhostedVoiceAgentApiConfig.',
      );
      _setConnectionState(state);
      throw ArgumentError('Unsupported API configuration type.');
    }
    _voice = voice;

    final parsedUri = Uri.parse(apiConfig.baseUrl);
    String extractedModel = apiConfig.params['model'] as String? ?? 'gpt-4o';
    Uri cleanUri = parsedUri;

    if (parsedUri.queryParameters.containsKey('model')) {
      final modelFromQuery = parsedUri.queryParameters['model'];
      if (modelFromQuery != null && modelFromQuery.isNotEmpty) {
        extractedModel = modelFromQuery;
      }
      final newQueryParameters =
          Map<String, String>.from(parsedUri.queryParameters)..remove('model');
      cleanUri = parsedUri.replace(
        queryParameters: newQueryParameters.isEmpty ? null : newQueryParameters,
      );
    }

    _config = OaiCcConnectConfig(
      baseUrl: cleanUri,
      model: extractedModel,
      apiKey: apiConfig.apiKey,
      modality: apiConfig.modality,
      extraHeaders: const <String, String>{},
    );

    _setConnectionState(const RealtimeAdapterConnectionState.connected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _cleanupActiveCalls();
    await _cancelAudioInput();
    _setConnectionState(const RealtimeAdapterConnectionState.disconnected());
    _client.dispose();

    await _threadController.close();
    await _connectionController.close();
    await _errorController.close();
    await _assistantAudioController.close();
    await _assistantAudioCompletedController.close();
    await _userSpeakingStateController.close();
  }

  // ---------------------------------------------------------------------------
  // Audio Input / Output
  // ---------------------------------------------------------------------------

  @override
  Future<void> bindAudioInput(Stream<Uint8List>? audioStream) async {
    _ensureNotDisposed();
    await _cancelAudioInput();
    if (audioStream == null) {
      return;
    }

    // Chat Completions does not consume live microphone chunks directly.
    // CallService owns manual/PTT turn capture and submits completed turns via
    // sendAudioOneShot(). Keep the live binding only as a lifecycle boundary.
    _audioInputSubscription = audioStream.listen((_) {});
  }

  @override
  Future<void> setAudioTurnMode(RealtimeAudioTurnMode mode) async {
    _ensureNotDisposed();
  }

  // ---------------------------------------------------------------------------
  // User content & Tools (Stubs / Minimal functionality)
  // ---------------------------------------------------------------------------

  @override
  Future<void> registerTools(List<ToolDefinition> tools) async {
    _ensureNotDisposed();
    _tools = List<ToolDefinition>.unmodifiable(tools);
  }

  @override
  Future<void> setInstructions(String instructions) async {
    _ensureNotDisposed();
    final normalized = instructions.trim();
    _instructions = normalized.isEmpty ? '' : normalized;
  }

  @override
  Future<bool> applyProviderExtension(
      String extensionType, Map<String, dynamic> payload) async {
    return false; // Extension config not supported in v1
  }

  @override
  Future<String> sendAudioOneShot(Uint8List audioBytes) async {
    _ensureNotDisposed();
    await interrupt();

    final wavBase64 = OaiCcWavEncoder.encodeBase64(audioBytes);
    return _sendAudioTurn(wavBase64);
  }

  @override
  Future<String> sendText(String text) async {
    _ensureNotDisposed();
    await interrupt();

    final itemId = _nextLocalId();
    final userItem = RealtimeThreadItem(
      id: itemId,
      type: RealtimeThreadItemType.message,
      role: RealtimeThreadItemRole.user,
      status: RealtimeThreadItemStatus.completed,
      content: [RealtimeThreadTextPart(text: text, isDone: true)],
    );
    _thread.addItem(userItem);
    _emitThreadUpdate();

    // Fire text chat completion
    await _sendTextTurn(text);
    return itemId;
  }

  @override
  Future<String> sendImage(Uint8List imageBytes) async {
    _ensureNotDisposed();
    throw UnimplementedError(
        'Image input is not supported in OaiCcRealtimeAdapter v1.');
  }

  @override
  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  }) async {
    _ensureNotDisposed();
    await interrupt();

    final itemId = _nextLocalId();
    _thread.addItem(
      RealtimeThreadItem(
        id: itemId,
        type: RealtimeThreadItemType.functionCallOutput,
        role: RealtimeThreadItemRole.assistant,
        status: RealtimeThreadItemStatus.completed,
        callId: callId,
        output: output,
        toolOutputDisposition: disposition,
        toolErrorMessage: errorMessage,
      ),
    );
    _emitThreadUpdate();

    if (_allToolCallsHaveOutputs()) {
      final messages = _buildMessages();
      await _executeChatCompletion(messages);
    }
    return itemId;
  }

  bool _allToolCallsHaveOutputs() {
    final toolCallIds = _thread.items
        .where((item) => item.type == RealtimeThreadItemType.functionCall)
        .map((item) => item.callId)
        .whereType<String>()
        .toSet();

    final toolOutputIds = _thread.items
        .where((item) => item.type == RealtimeThreadItemType.functionCallOutput)
        .map((item) => item.callId)
        .whereType<String>()
        .toSet();

    return toolCallIds.every((id) => toolOutputIds.contains(id));
  }

  @override
  void cancelFunctionCalls(
      {Set<String> itemIds = const <String>{},
      Set<String> callIds = const <String>{}}) {}

  // ---------------------------------------------------------------------------
  // Response Control
  // ---------------------------------------------------------------------------

  @override
  Future<void> interrupt() async {
    _ensureNotDisposed();
    await _cleanupActiveCalls();
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  Future<void> _cleanupActiveCalls() async {
    await _responseStreamSubscription?.cancel();
    _responseStreamSubscription = null;
    _client.cancelOngoingRequest();
  }

  Future<void> _cancelAudioInput() async {
    await _audioInputSubscription?.cancel();
    _audioInputSubscription = null;
  }

  Future<String> _sendAudioTurn(String wavBase64) async {
    final userItemId = _nextLocalId();
    final audioPart = RealtimeThreadAudioPart(
      transcript: null,
      isDone: true,
    );
    audioPart.replaceAudio(wavBase64);

    final userItem = RealtimeThreadItem(
      id: userItemId,
      type: RealtimeThreadItemType.message,
      role: RealtimeThreadItemRole.user,
      status: RealtimeThreadItemStatus.completed,
      content: [audioPart],
    );
    _thread.addItem(userItem);
    _emitThreadUpdate();

    final messages = _buildMessages();

    await _executeChatCompletion(messages);
    return userItemId;
  }

  Future<void> _sendTextTurn(String text) async {
    final messages = _buildMessages();

    await _executeChatCompletion(messages);
  }

  List<OaiCcMessage> _buildMessages() {
    final messages = <OaiCcMessage>[
      if (_instructions.isNotEmpty)
        OaiCcTextMessage(role: 'system', content: _instructions),
    ];

    final processedCallIds = <String>{};

    for (int i = 0; i < _thread.items.length; i++) {
      final item = _thread.items[i];

      if (item.type == RealtimeThreadItemType.functionCallOutput) {
        continue;
      }

      if (item.type == RealtimeThreadItemType.functionCall) {
        if (item.callId != null && processedCallIds.contains(item.callId)) {
          continue;
        }

        final currentToolCalls = <RealtimeThreadItem>[];
        int j = i;
        while (j < _thread.items.length) {
          final nextItem = _thread.items[j];
          if (nextItem.type == RealtimeThreadItemType.functionCall) {
            if (nextItem.callId != null &&
                nextItem.name != null &&
                nextItem.arguments != null) {
              currentToolCalls.add(nextItem);
            }
            j++;
          } else if (nextItem.type ==
              RealtimeThreadItemType.functionCallOutput) {
            j++;
          } else {
            break;
          }
        }
        i = j - 1;

        if (currentToolCalls.isNotEmpty) {
          final toolCallParts = currentToolCalls.map((tc) {
            processedCallIds.add(tc.callId!);
            return OaiCcToolCallPart(
              id: tc.callId!,
              name: tc.name!,
              arguments: tc.arguments!,
            );
          }).toList();
          messages.add(OaiCcAssistantToolCallMessage(toolCalls: toolCallParts));

          for (final tc in currentToolCalls) {
            RealtimeThreadItem? outputItem;
            for (final x in _thread.items) {
              if (x.type == RealtimeThreadItemType.functionCallOutput &&
                  x.callId == tc.callId) {
                outputItem = x;
                break;
              }
            }
            if (outputItem != null && outputItem.output != null) {
              messages.add(OaiCcToolResultMessage(
                callId: tc.callId!,
                content: outputItem.output!,
              ));
            }
          }
        }
        continue;
      }

      if (item.type != RealtimeThreadItemType.message) continue;
      final roleStr = switch (item.role) {
        RealtimeThreadItemRole.user => 'user',
        RealtimeThreadItemRole.assistant => 'assistant',
        RealtimeThreadItemRole.system => 'system',
        null => null,
      };
      if (roleStr == null) continue;

      if (roleStr == 'assistant') {
        final audioId = _assistantAudioIds[item.id];
        if (audioId != null) {
          messages.add(OaiCcAssistantAudioMessage(audioId: audioId));
          continue;
        }
      } else if (roleStr == 'user') {
        final audioPart =
            item.content.whereType<RealtimeThreadAudioPart>().firstOrNull;
        if (audioPart != null) {
          final audioBase64 = audioPart.fullAudioBase64;
          if (audioBase64.isNotEmpty) {
            messages.add(
                OaiCcAudioMessage(role: roleStr, audioBase64: audioBase64));
            continue;
          }
        }
      }

      final textContent = item.content
          .map((part) {
            if (part is RealtimeThreadTextPart) {
              return part.text;
            } else if (part is RealtimeThreadAudioPart) {
              return part.transcript ?? '';
            }
            return '';
          })
          .join('\n')
          .trim();

      if (textContent.isNotEmpty) {
        messages.add(OaiCcTextMessage(role: roleStr, content: textContent));
      }
    }

    return messages;
  }

  Future<void> _executeChatCompletion(List<OaiCcMessage> messages) async {
    if (_config == null) return;

    _activeToolCallIndexToItemId.clear();

    final assistantItemId = _nextLocalId();
    final assistantTextPart = RealtimeThreadTextPart(text: '', isDone: false);
    final assistantItem = RealtimeThreadItem(
      id: assistantItemId,
      type: RealtimeThreadItemType.message,
      role: RealtimeThreadItemRole.assistant,
      status: RealtimeThreadItemStatus.inProgress,
      content: [assistantTextPart],
    );
    _thread.addItem(assistantItem);
    _emitThreadUpdate();

    final isAudioModel = _config!.modality == VoiceAgentModality.audio;

    final requestTools = _tools.map((t) {
      return {
        'type': 'function',
        'function': {
          'name': t.toolKey,
          'description': t.description,
          'parameters': t.parametersSchema,
        },
      };
    }).toList();

    final request = OaiCcRequest(
      model: _config!.model,
      messages: messages,
      stream: true,
      modalities: isAudioModel ? ['text', 'audio'] : null,
      additionalParams: {
        if (isAudioModel)
          'audio': {
            'voice': _voice ?? 'alloy',
            'format': 'pcm16',
          },
        if (requestTools.isNotEmpty) ...{
          'tools': requestTools,
          'tool_choice': 'auto',
        },
      },
    );

    final eventStream = _client.streamCompletions(
      config: _config!,
      requestPayload: request,
    );

    bool hasToolCalls = false;

    _responseStreamSubscription = eventStream.listen(
      (event) {
        if (event is OaiCcContentDeltaEvent) {
          assistantTextPart.appendDelta(event.content);
          _emitThreadUpdate();
        } else if (event is OaiCcToolCallDeltaEvent) {
          hasToolCalls = true;
          final item = _findOrCreateToolCallItem(event);
          if (event.name != null) {
            item.name = event.name;
          }
          if (event.arguments != null) {
            item.arguments = (item.arguments ?? '') + event.arguments!;
          }
          _emitThreadUpdate();
        } else if (event is OaiCcAudioDeltaEvent) {
          if (event.audioId != null && event.audioId!.isNotEmpty) {
            _assistantAudioIds[assistantItemId] = event.audioId!;
          }
          if (event.transcript != null && event.transcript!.isNotEmpty) {
            assistantTextPart.appendDelta(event.transcript!);
            _emitThreadUpdate();
          }
          if (event.audioBase64 != null && event.audioBase64!.isNotEmpty) {
            try {
              final decodedBytes = base64Decode(event.audioBase64!);
              _assistantAudioController.add(decodedBytes);
            } catch (err) {
              _errorController.add(
                RealtimeAdapterError(
                  code: 'audio_decode_error',
                  message: 'Failed to decode audio delta: $err',
                ),
              );
            }
          }
        } else if (event is OaiCcFinishedEvent) {
          if (hasToolCalls && assistantTextPart.text.isEmpty) {
            _thread.removeItem(assistantItemId);
          } else {
            assistantItem.markDone();
          }
          // Also mark any in-progress tool calls as completed/ready since they finished streaming
          for (final item in _thread.items) {
            if (item.type == RealtimeThreadItemType.functionCall &&
                item.status == RealtimeThreadItemStatus.inProgress) {
              item.status = RealtimeThreadItemStatus.completed;
            }
          }
          _assistantAudioCompletedController.add(null);
          _emitThreadUpdate();
          _responseStreamSubscription?.cancel();
          _responseStreamSubscription = null;
        } else if (event is OaiCcErrorEvent) {
          assistantItem.markIncomplete();
          _emitThreadUpdate();
          _errorController.add(
            RealtimeAdapterError(
              code: 'chat_completions_error',
              message: event.message,
            ),
          );
          _responseStreamSubscription?.cancel();
          _responseStreamSubscription = null;
        }
      },
      onError: (err) {
        assistantItem.markIncomplete();
        _emitThreadUpdate();
        _errorController.add(
          RealtimeAdapterError(
            code: 'stream_error',
            message: err.toString(),
          ),
        );
      },
      cancelOnError: true,
    );
  }

  String _nextLocalId() {
    _localIdCounter++;
    return 'cc_item_$_localIdCounter';
  }

  RealtimeThreadItem _findOrCreateToolCallItem(OaiCcToolCallDeltaEvent event) {
    final existingItemId = _activeToolCallIndexToItemId[event.index];
    if (existingItemId != null) {
      final existing = _thread.findItem(existingItemId);
      if (existing != null) {
        if (event.id != null) {
          existing.callId = event.id;
          _toolCallIdToItemId[event.id!] = existingItemId;
        }
        return existing;
      }
    }

    final callId = event.id;
    if (callId != null) {
      final itemId = _toolCallIdToItemId[callId];
      if (itemId != null) {
        final existing = _thread.findItem(itemId);
        if (existing != null) {
          _activeToolCallIndexToItemId[event.index] = itemId;
          return existing;
        }
      }
    }

    final itemId = _nextLocalId();
    _activeToolCallIndexToItemId[event.index] = itemId;
    if (callId != null) {
      _toolCallIdToItemId[callId] = itemId;
    }

    final item = RealtimeThreadItem(
      id: itemId,
      type: RealtimeThreadItemType.functionCall,
      role: RealtimeThreadItemRole.assistant,
      status: RealtimeThreadItemStatus.inProgress,
      callId: callId,
      name: event.name,
      arguments: event.arguments,
    );
    _thread.addItem(item);
    return item;
  }

  void _emitThreadUpdate() {
    if (!_threadController.isClosed) {
      _threadController.add(_thread);
    }
  }

  void _setConnectionState(RealtimeAdapterConnectionState value) {
    _connectionState = value;
    if (!_connectionController.isClosed) {
      _connectionController.add(value);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('OaiCcRealtimeAdapter is already disposed.');
    }
  }
}
