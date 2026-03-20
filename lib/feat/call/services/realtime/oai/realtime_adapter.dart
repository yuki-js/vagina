import 'dart:async';
import 'dart:typed_data';

import '../realtime_adapter.dart';

import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'realtime_binding.dart';
import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_event.dart';

/// OpenAI / Azure OpenAI implementation of [RealtimeAdapter].
///
/// Owns all protocol-specific defaults (audio format, VAD, transcription model).
/// The caller only provides voice + instructions at connect time.
final class OaiRealtimeAdapter implements RealtimeAdapter {
  final OaiRealtimeClient _client;
  final RealtimeThread _thread;
  final StreamController<RealtimeThread> _threadController =
      StreamController<RealtimeThread>.broadcast();
  final StreamController<RealtimeAdapterConnectionState> _connectionController =
      StreamController<RealtimeAdapterConnectionState>.broadcast();
  final StreamController<RealtimeAdapterError> _errorController =
      StreamController<RealtimeAdapterError>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  StreamSubscription<Uint8List>? _audioInputSubscription;
  List<ToolDefinition> _tools = const <ToolDefinition>[];
  int _localIdCounter = 0;
  bool _disposed = false;

  OaiRealtimeAdapter({OaiRealtimeClient? client, String? threadId})
      : _client = client ?? OaiRealtimeClient(),
        _thread = RealtimeThread(
          id: threadId ?? _makeThreadId(),
        ) {
    _subscriptions.addAll([
      _client.connectionStates.listen((state) {
        _connectionController.add(
          switch (state.phase) {
            OaiRealtimeConnectionPhase.idle =>
              const RealtimeAdapterConnectionState.idle(),
            OaiRealtimeConnectionPhase.connecting ||
            OaiRealtimeConnectionPhase.reconnecting =>
              const RealtimeAdapterConnectionState.connecting(),
            OaiRealtimeConnectionPhase.connected =>
              const RealtimeAdapterConnectionState.connected(),
            OaiRealtimeConnectionPhase.disconnecting =>
              const RealtimeAdapterConnectionState.disconnecting(),
            OaiRealtimeConnectionPhase.disconnected =>
              RealtimeAdapterConnectionState.disconnected(
                message: state.message,
              ),
            OaiRealtimeConnectionPhase.failed =>
              RealtimeAdapterConnectionState.failed(
                message: state.message,
                error: state.error,
              ),
          },
        );
      }),
      _client.connectionErrors.listen((error) {
        _errorController.add(
          RealtimeAdapterError(
            code: error.code,
            message: error.message,
            cause: error.cause,
          ),
        );
      }),
      _client.errorEvents.listen((event) {
        _errorController.add(
          RealtimeAdapterError(
            code: event.error.code ?? event.error.type,
            message: event.error.message,
            cause: event.rawPayload,
          ),
        );
      }),
      _client.conversationCreatedEvents.listen((event) {
        _thread.conversationId = event.conversation.id;
        _emitThreadUpdate();
      }),
      _client.conversationItemCreatedEvents.listen((event) {
        _upsertConversationItem(event.item);
        _emitThreadUpdate();
      }),
      _client.conversationItemDeletedEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        if (_thread.removeItem(itemId)) {
          _emitThreadUpdate();
        }
      }),
      _client.responseOutputItemAddedEvents.listen((event) {
        _upsertConversationItem(event.item);
        _emitThreadUpdate();
      }),
      _client.responseOutputItemDoneEvents.listen((event) {
        final item = _upsertConversationItem(event.item);
        item.status = RealtimeThreadItemStatus.fromWireValue(event.item.status);
        _emitThreadUpdate();
      }),
      _client.responseContentPartAddedEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        _mergeContentPart(
          item,
          event.part,
          contentIndex: event.contentIndex,
          isDone: false,
        );
        _emitThreadUpdate();
      }),
      _client.responseContentPartDoneEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        _mergeContentPart(
          item,
          event.part,
          contentIndex: event.contentIndex,
          isDone: true,
        );
        _emitThreadUpdate();
      }),
      _client.responseOutputTextDeltaEvents.listen((event) {
        final itemId = event.itemId;
        final delta = event.delta;
        if (itemId == null || itemId.isEmpty || delta == null) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        final textPart = _findOrCreateTextPart(
          item,
          contentIndex: event.contentIndex,
        );
        textPart.appendDelta(delta);
        _emitThreadUpdate();
      }),
      _client.responseOutputTextDoneEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        if (event.text != null) {
          final textPart = _findOrCreateTextPart(
            item,
            contentIndex: event.contentIndex,
          );
          textPart
            ..replaceText(event.text!)
            ..markDone();
        } else if (event.contentIndex != null) {
          item.findContentPart(event.contentIndex!)?.markDone();
        }
        _emitThreadUpdate();
      }),
      _client.responseOutputAudioDeltaEvents.listen((event) {
        final itemId = event.itemId;
        final delta = event.delta;
        if (itemId == null || itemId.isEmpty || delta == null) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        final audioPart = _findOrCreateAudioPart(
          item,
          contentIndex: event.contentIndex,
        );
        audioPart.appendAudioDelta(delta);
        _emitThreadUpdate();
      }),
      _client.responseOutputAudioDoneEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        _findContentPartOfType<RealtimeThreadAudioPart>(
          item,
          contentIndex: event.contentIndex,
        )?.markDone();
        _emitThreadUpdate();
      }),
      _client.responseOutputAudioTranscriptDeltaEvents.listen((event) {
        final itemId = event.itemId;
        final delta = event.delta;
        if (itemId == null || itemId.isEmpty || delta == null) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        final audioPart = _findOrCreateAudioPart(
          item,
          contentIndex: event.contentIndex,
        );
        audioPart.appendTranscriptDelta(delta);
        _emitThreadUpdate();
      }),
      _client.responseOutputAudioTranscriptDoneEvents.listen((event) {
        final itemId = event.itemId;
        final transcript = event.transcript;
        if (itemId == null || itemId.isEmpty || transcript == null) {
          return;
        }
        final item = _ensureAssistantMessageItem(itemId);
        final audioPart = _findOrCreateAudioPart(
          item,
          contentIndex: event.contentIndex,
        );
        audioPart
          ..replaceTranscript(transcript)
          ..markDone();
        _emitThreadUpdate();
      }),
      _client.responseFunctionCallArgumentsDeltaEvents.listen((event) {
        final itemId = event.itemId;
        final delta = event.delta;
        if (itemId == null || itemId.isEmpty || delta == null) {
          return;
        }
        final item = _ensureFunctionCallItem(itemId, callId: event.callId);
        item.arguments = (item.arguments ?? '') + delta;
        _emitThreadUpdate();
      }),
      _client.responseFunctionCallArgumentsDoneEvents.listen((event) {
        final itemId = event.itemId;
        if (itemId == null || itemId.isEmpty) {
          return;
        }
        final item = _ensureFunctionCallItem(
          itemId,
          callId: event.callId,
          name: event.name,
        );
        item.callId = event.callId ?? item.callId;
        item.name = event.name ?? item.name;
        item.arguments = event.arguments ?? item.arguments;
        _emitThreadUpdate();
      }),
    ]);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  @override
  RealtimeThread get thread => _thread;

  @override
  Stream<RealtimeThread> get threadUpdates => _threadController.stream;

  @override
  Stream<RealtimeAdapterConnectionState> get connectionStates =>
      _connectionController.stream;

  @override
  Stream<RealtimeAdapterError> get errors => _errorController.stream;

  @override
  bool get isConnected => _client.isConnected;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(
    VoiceAgentApiConfig apiConfig, {
    String? voice,
    String? instructions,
  }) async {
    _ensureNotDisposed();
    final selfHosted = apiConfig is SelfhostedVoiceAgentApiConfig
        ? apiConfig
        : throw UnsupportedError(
            'OaiRealtimeAdapter only supports SelfhostedVoiceAgentApiConfig.',
          );
    await _client.connect(_toOaiConnectConfig(selfHosted));
    await _client.updateSession(
      _buildSessionConfig(
        voice: voice,
        instructions: instructions,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _ensureNotDisposed();
    await _cancelAudioInput();
    await _client.disconnect();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _cancelAudioInput();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _client.dispose();
    await _threadController.close();
    await _connectionController.close();
    await _errorController.close();
  }

  // ---------------------------------------------------------------------------
  // Audio input
  // ---------------------------------------------------------------------------

  @override
  Future<void> bindAudioInput(Stream<Uint8List> audioStream) async {
    _ensureNotDisposed();
    await _cancelAudioInput();
    _audioInputSubscription = audioStream.listen(
      (bytes) => _client.appendInputAudio(bytes),
      onError: (Object error) {
        _errorController.add(
          RealtimeAdapterError(
            code: 'audio_input_error',
            message: 'Audio input stream error.',
            cause: error,
          ),
        );
      },
    );
  }

  @override
  Future<void> unbindAudioInput() async {
    _ensureNotDisposed();
    await _cancelAudioInput();
  }

  // ---------------------------------------------------------------------------
  // Tool configuration
  // ---------------------------------------------------------------------------

  @override
  Future<void> registerTools(List<ToolDefinition> tools) async {
    _ensureNotDisposed();
    _tools = List<ToolDefinition>.unmodifiable(tools);
    if (!isConnected) {
      return;
    }

    await _client.updateSession({
      'tools': _tools.map((tool) => tool.toRealtimeJson()).toList(),
      'tool_choice': _tools.isEmpty ? 'none' : 'auto',
    });
  }

  // ---------------------------------------------------------------------------
  // User content
  // ---------------------------------------------------------------------------

  @override
  Future<String> sendText(String text) async {
    _ensureNotDisposed();
    final itemId = _nextLocalId('msg');
    await _client.createConversationItem(
      item: {
        'id': itemId,
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': text,
          },
        ],
      },
    );
    await _client.createResponse();
    return itemId;
  }

  @override
  Future<String> sendImage(String dataUri) async {
    _ensureNotDisposed();
    final itemId = _nextLocalId('msg');
    await _client.createConversationItem(
      item: {
        'id': itemId,
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_image',
            'image_url': dataUri,
            'detail': 'auto',
          },
        ],
      },
    );
    await _client.createResponse();
    return itemId;
  }

  @override
  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
  }) async {
    _ensureNotDisposed();
    final itemId = _nextLocalId('tool');
    await _client.createConversationItem(
      item: {
        'id': itemId,
        'type': 'function_call_output',
        'call_id': callId,
        'output': output,
      },
    );
    await _client.createResponse();
    return itemId;
  }

  // ---------------------------------------------------------------------------
  // Response control
  // ---------------------------------------------------------------------------

  @override
  Future<void> interrupt() async {
    _ensureNotDisposed();
    await _client.cancelResponse();
    await _client.clearOutputAudioBuffer();
  }

  // ---------------------------------------------------------------------------
  // Internal — thread projection
  // ---------------------------------------------------------------------------

  RealtimeThreadItem _upsertConversationItem(
    OaiRealtimeConversationItem conversationItem,
  ) {
    final existing = _thread.findItem(conversationItem.id);
    if (existing != null) {
      existing.role = _mapRole(conversationItem.role);
      existing.status = RealtimeThreadItemStatus.fromWireValue(
        conversationItem.status,
      );
      existing.callId = conversationItem.callId ?? existing.callId;
      existing.name = conversationItem.name ?? existing.name;
      existing.arguments = conversationItem.arguments ?? existing.arguments;
      existing.output = conversationItem.output ?? existing.output;
      if (existing.content.isEmpty && conversationItem.content.isNotEmpty) {
        for (final part in conversationItem.content) {
          _mergeContentPart(existing, part, isDone: true);
        }
      }
      return existing;
    }

    final item = RealtimeThreadItem(
      id: conversationItem.id,
      type: _mapItemType(conversationItem.type),
      role: _mapRole(conversationItem.role),
      status: RealtimeThreadItemStatus.fromWireValue(conversationItem.status),
      callId: conversationItem.callId,
      name: conversationItem.name,
      arguments: conversationItem.arguments,
      output: conversationItem.output,
    );
    for (final part in conversationItem.content) {
      _mergeContentPart(item, part, isDone: true);
    }
    _thread.addItem(item);
    return item;
  }

  RealtimeThreadItem _ensureAssistantMessageItem(String itemId) {
    final existing = _thread.findItem(itemId);
    if (existing != null) {
      return existing;
    }
    final item = RealtimeThreadItem(
      id: itemId,
      type: RealtimeThreadItemType.message,
      role: RealtimeThreadItemRole.assistant,
      status: RealtimeThreadItemStatus.inProgress,
    );
    _thread.addItem(item);
    return item;
  }

  RealtimeThreadItem _ensureFunctionCallItem(
    String itemId, {
    String? callId,
    String? name,
  }) {
    final existing = _thread.findItem(itemId);
    if (existing != null) {
      existing.callId = callId ?? existing.callId;
      existing.name = name ?? existing.name;
      return existing;
    }
    final item = RealtimeThreadItem(
      id: itemId,
      type: RealtimeThreadItemType.functionCall,
      role: RealtimeThreadItemRole.assistant,
      status: RealtimeThreadItemStatus.inProgress,
      callId: callId,
      name: name,
    );
    _thread.addItem(item);
    return item;
  }

  T? _findContentPartOfType<T extends RealtimeThreadContentPart>(
    RealtimeThreadItem item, {
    int? contentIndex,
  }) {
    if (contentIndex != null) {
      final part = item.findContentPart(contentIndex);
      return part is T ? part : null;
    }

    for (final part in item.content.reversed) {
      if (part is T) {
        return part;
      }
    }
    return null;
  }

  RealtimeThreadTextPart _findOrCreateTextPart(
    RealtimeThreadItem item, {
    int? contentIndex,
  }) {
    final existing = _findContentPartOfType<RealtimeThreadTextPart>(
      item,
      contentIndex: contentIndex,
    );
    if (existing != null) {
      return existing;
    }

    final created = RealtimeThreadTextPart();
    item.putContentPart(created, contentIndex: contentIndex);
    return created;
  }

  RealtimeThreadAudioPart _findOrCreateAudioPart(
    RealtimeThreadItem item, {
    int? contentIndex,
  }) {
    final existing = _findContentPartOfType<RealtimeThreadAudioPart>(
      item,
      contentIndex: contentIndex,
    );
    if (existing != null) {
      return existing;
    }

    final created = RealtimeThreadAudioPart();
    item.putContentPart(created, contentIndex: contentIndex);
    return created;
  }

  void _mergeContentPart(
    RealtimeThreadItem item,
    OaiRealtimeContentPart part, {
    int? contentIndex,
    required bool isDone,
  }) {
    switch (part.type) {
      case 'text':
      case 'input_text':
      case 'output_text':
        final textPart = _findOrCreateTextPart(item, contentIndex: contentIndex);
        if (part.text != null && part.text!.isNotEmpty) {
          textPart.replaceText(part.text!);
        }
        if (isDone) {
          textPart.markDone();
        }
        return;
      case 'audio':
      case 'input_audio':
      case 'output_audio':
        final audioPart = _findOrCreateAudioPart(
          item,
          contentIndex: contentIndex,
        );
        if (part.audio != null && part.audio!.isNotEmpty) {
          audioPart.replaceAudio(part.audio!);
        }
        if (part.transcript != null && part.transcript!.isNotEmpty) {
          audioPart.replaceTranscript(part.transcript!);
        }
        if (isDone) {
          audioPart.markDone();
        }
        return;
      case 'input_image':
        item.putContentPart(
          RealtimeThreadImagePart(
            imageUrl: part.imageUrl ?? '',
            detail: part.detail ?? 'auto',
          ),
          contentIndex: contentIndex,
        );
        return;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — session config mapping
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildSessionConfig({
    String? voice,
    String? instructions,
  }) {
    return {
      'modalities': ['text', 'audio'],
      if (voice != null) 'voice': voice,
      if (instructions != null) 'instructions': instructions,
      'input_audio_format': 'pcm16',
      'output_audio_format': 'pcm16',
      'input_audio_transcription': {
        'model': 'gpt-4o-transcribe',
      },
      'turn_detection': {
        'type': 'semantic_vad',
        'eagerness': 'low',
        'create_response': true,
        'interrupt_response': true,
      },
      if (_tools.isNotEmpty)
        'tools': _tools.map((tool) => tool.toRealtimeJson()).toList(),
      if (_tools.isNotEmpty) 'tool_choice': 'auto',
    };
  }

  // ---------------------------------------------------------------------------
  // Internal — config mapping
  // ---------------------------------------------------------------------------

  OaiRealtimeConnectConfig _toOaiConnectConfig(
    SelfhostedVoiceAgentApiConfig config,
  ) {
    final provider = config.provider.toLowerCase();

    if (provider == 'openai' || provider == 'open_ai' || provider == 'open-ai') {
      final baseUri = config.baseUrl.isEmpty ? null : Uri.parse(config.baseUrl);
      return OpenAiRealtimeConnectConfig(
        apiKey: config.apiKey,
        model: config.model,
        baseUri: baseUri,
        organization: config.params['organization'] as String?,
        project: config.params['project'] as String?,
      );
    }

    if (provider == 'azure' ||
        provider == 'azureopenai' ||
        provider == 'azure_openai' ||
        provider == 'azure-openai') {
      if (config.baseUrl.isEmpty) {
        throw ArgumentError('Azure OpenAI requires baseUrl as endpoint.');
      }
      return AzureOpenAiRealtimeConnectConfig(
        apiKey: config.apiKey,
        endpoint: Uri.parse(config.baseUrl),
        deployment: (config.params['deployment'] as String?) ?? config.model,
        apiVersion:
            (config.params['apiVersion'] as String?) ?? '2025-04-01-preview',
      );
    }

    throw UnsupportedError(
      'OaiRealtimeAdapter does not support provider: ${config.provider}',
    );
  }

  // ---------------------------------------------------------------------------
  // Internal — helpers
  // ---------------------------------------------------------------------------

  RealtimeThreadItemType _mapItemType(String value) {
    return switch (value) {
      'function_call' => RealtimeThreadItemType.functionCall,
      'function_call_output' => RealtimeThreadItemType.functionCallOutput,
      _ => RealtimeThreadItemType.message,
    };
  }

  RealtimeThreadItemRole? _mapRole(String? value) {
    return switch (value) {
      'system' => RealtimeThreadItemRole.system,
      'user' => RealtimeThreadItemRole.user,
      'assistant' => RealtimeThreadItemRole.assistant,
      _ => null,
    };
  }

  void _emitThreadUpdate() {
    if (!_threadController.isClosed) {
      _threadController.add(_thread);
    }
  }

  String _nextLocalId(String prefix) {
    _localIdCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localIdCounter';
  }

  Future<void> _cancelAudioInput() async {
    await _audioInputSubscription?.cancel();
    _audioInputSubscription = null;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('OaiRealtimeAdapter is already disposed.');
    }
  }

  static String _makeThreadId() {
    return 'thread_${DateTime.now().microsecondsSinceEpoch}';
  }
}
