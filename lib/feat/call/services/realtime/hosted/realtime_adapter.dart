// VhrpRealtimeAdapter — Step 8: interrupt, resume reconnect.
//
// Scope of this file (cumulative):
//   - Steps 3–7 (connection, thread projection, user content, audio I/O, tools).
//   - Step 8 additions:
//       • interrupt()             → assistant.interrupt (one-way, reason:"barge_in")
//       • Resume reconnect loop:
//           - disconnected/failed while _sessionId != null → auto-reconnect
//           - session.open + resume.sessionId (§6.1 step 2)
//           - session.resumed → thread.sync.request("reconnected") → snapshot
//           - error(resume.not_available) → fresh session.open (no resume)
//           - Exponential backoff: 500 ms × 2^attempt, max 16 s, max 5 attempts
//           - dispose-safe: _disposed guard checked before every reconnect step
//       • Resume post-state policy (§6.1):
//           - session.resumed path: tools/instructions/extensions NOT re-sent
//             (session preserved server-side); liveAudioSequence reset; audio
//             subscription kept alive.
//           - resume.not_available → new session path: session.open carries the
//             current canonical session state; buffers flush only state that is
//             not part of session.open.
//       • Single recovery path: both desync (patch_apply_failed via §5.5) and
//         resume both resolve through thread.sync.request → thread.snapshot
//         → _projector.applySnapshot — handled by the existing _onThreadSnapshot.
//
// NOT in this file:
//   - RealtimeAdapterFactory wiring — Step 9.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logging/logging.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/call/models/realtime/realtime_adapter_models.dart';
import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

import 'vhrp_cbor_codec.dart';
import 'vhrp_messages.dart';
import 'vhrp_debug_format.dart';
import 'vhrp_thread_projector.dart';
import 'vhrp_transport.dart';
import 'websocket_vhrp_transport.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Frozen copy of [VhrpRealtimeAdapter.connect] parameters so the reconnect
/// loop can rebuild a `session.open` message without re-calling connect().
final class _ConnectConfig {
  final String modelId;
  final String? voice;

  _ConnectConfig({required this.modelId, this.voice});
}

// ─────────────────────────────────────────────────────────────────────────────
// VhrpRealtimeAdapter
// ─────────────────────────────────────────────────────────────────────────────

/// VHRP/1 implementation of [RealtimeAdapter].
///
/// Connects to the self-hosted Hosted Realtime endpoint over a WebSocket using
/// the VHRP/1 CBOR sub-protocol (`vhrp.cbor.v1`).
///
/// Constructor injection:
///   - [transport]      : the WebSocket transport (inject [FakeVhrpTransport]
///                        in tests; defaults to [WebSocketVhrpTransport]).
///   - [tokenProvider]  : async supplier of the JWT placed in
///                        `session.open.body.token`.  If it returns `null`,
///                        [connect] emits [RealtimeAdapterError] on [errors],
///                        transitions to [failed], and throws [StateError].
///   - [urlResolver]    : optional override for URL resolution (test seam).
///                        Defaults to [AppConfig.resolveApiBaseUrl] +
///                        scheme/path rewrite.
///
/// connectionState derivation (§6.2 of handoff doc):
///   - Transport [connecting]  → adapter [connecting].
///   - Transport [connected]   → adapter stays [connecting] (session
///     negotiation still pending).
///   - session.ready / session.resumed received → adapter [connected].
///   - Transport [disconnecting] → adapter [disconnecting].
///   - Transport [disconnected]  → adapter [disconnected].
///   - Transport [failed]        → adapter [failed].
///   - Unrecoverable error from server → adapter [failed].
final class VhrpRealtimeAdapter implements RealtimeAdapter {
  static final Logger _logger = Logger('VhrpRealtimeAdapter');

  // ── Dependencies ────────────────────────────────────────────────────────────

  final VhrpRealtimeTransport _transport;
  final Future<String?> Function() _tokenProvider;

  /// Optional URL resolver seam.  Receives [isDebugMode] and returns the
  /// WebSocket URI to connect to.  Defaults to production logic.
  final Uri Function(bool isDebugMode)? _urlResolver;

  static const VhrpCborCodec _codec = VhrpCborCodec();
  static const VhrpThreadProjector _projector = VhrpThreadProjector();

  // ── Stream controllers ───────────────────────────────────────────────────

  final StreamController<RealtimeAdapterConnectionState>
  _connectionStateController =
      StreamController<RealtimeAdapterConnectionState>.broadcast();

  final StreamController<RealtimeAdapterError> _errorController =
      StreamController<RealtimeAdapterError>.broadcast();

  final StreamController<RealtimeThread> _threadController =
      StreamController<RealtimeThread>.broadcast();

  /// Broadcast stream for assistant audio output — wired in Step 5.
  final StreamController<Uint8List> _assistantAudioController =
      StreamController<Uint8List>.broadcast();

  /// Fires at assistant audio response boundary — wired in Step 5.
  final StreamController<void> _assistantAudioCompletedController =
      StreamController<void>.broadcast();

  /// VAD speaking state — wired in Step 5.
  final StreamController<bool> _userSpeakingController =
      StreamController<bool>.broadcast();

  // ── Mutable state ────────────────────────────────────────────────────────

  RealtimeAdapterConnectionState _connectionState =
      const RealtimeAdapterConnectionState.idle();

  bool _disposed = false;
  // ignore: prefer_final_fields — mutated in Step 5 (VAD state handler).
  bool _isUserSpeaking = false;

  /// Completer resolved by _onSessionReady / _onSessionResumed.
  /// Completed with an error when transport fails before session.ready.
  Completer<void>? _sessionReadyCompleter;

  /// Session ID from the most recent session.ready / session.resumed.
  /// Null before the first session is established.  Used as the resume token
  /// in session.open.body.resume on reconnect (§6.1).
  String? _sessionId;
  // ignore: unused_field — stored for reconnect threadId tracking; may be used by step 9 factory.
  String? _threadId;
  // ignore: unused_field — stored for reconnect conversationId tracking; may be used by step 9 factory.
  String? _conversationId;

  // ── Reconnect state (Step 8) ─────────────────────────────────────────────

  /// True while the automatic reconnect loop is running.
  /// Guards against concurrent reconnect attempts.
  bool _isReconnecting = false;

  /// Number of consecutive reconnect attempts since the last successful
  /// session.ready / session.resumed.  Reset to 0 on success.
  int _reconnectAttempt = 0;

  /// Maximum number of reconnect attempts before giving up.
  static const int _maxReconnectAttempts = 5;

  /// Base delay for exponential backoff (ms).
  static const int _reconnectBaseMs = 500;

  /// Maximum backoff delay (ms).
  static const int _reconnectMaxMs = 16000;

  /// Stored connect() parameters so reconnect can rebuild session.open
  /// identically (apiConfig for modelId and voice). Instructions are kept in
  /// [_sessionInstructions] because [setInstructions] is the sole prompt entry
  /// point before and after connect.
  _ConnectConfig? _connectConfig;

  // ── Thread model ─────────────────────────────────────────────────────────

  /// Current projected thread.  Initialised as an empty shell; replaced
  /// wholesale when a `thread.snapshot` arrives (Step 4).
  /// Must NOT be final — snapshot application swaps the reference entirely
  /// because [RealtimeThread.id] is final (cannot be mutated in-place).
  RealtimeThread _thread = RealtimeThread(id: 'vhrp-local-thread');

  // ── Audio turn mode ──────────────────────────────────────────────────────

  /// Current audio turn mode.  Defaults to [voiceActivity] to match the
  /// [SessionOpenMsg.audioTurnMode] value sent in [connect].
  ///
  /// Used by [_handleLiveAudioChunk] to gate outbound live audio: chunks are
  /// forwarded only in [voiceActivity] mode (OAI parity — the server may
  /// discard live audio in [manual] mode, so we suppress it client-side too).
  RealtimeAudioTurnMode _audioTurnMode = RealtimeAudioTurnMode.voiceActivity;

  // ── ack/error correlation (Step 7) ──────────────────────────────────────

  /// Pending request completers keyed by messageId.
  ///
  /// When the client sends a C2S message that expects an ack, a [Completer] is
  /// stored here under the message's `messageId`.  When the server replies with
  /// [AckMsg] or [ErrorMsg] carrying the matching `replyTo`, the completer is
  /// completed (success) or completed with an error (failure) respectively.
  ///
  /// Completers that are still open at [dispose] time are completed with a
  /// [StateError] so callers awaiting them receive a clean termination signal.
  final Map<String, Completer<AckMsg>> _pendingRequests =
      <String, Completer<AckMsg>>{};

  // ── Session capabilities (Step 7) ────────────────────────────────────────

  /// Extension keys advertised by the server in `session.ready.capabilities`.
  ///
  /// Used to guard `applyProviderExtension` calls: if the requested extension
  /// key is absent here, we return `false` immediately without a round-trip.
  /// Populated by [_onSessionReady]; cleared on each new [connect] call.
  List<String> _capabilityExtensions = const <String>[];

  // ── Pre-connect buffers (Step 7) ─────────────────────────────────────────

  /// Most-recent tools list passed to [registerTools] before the session was
  /// ready.  `null` means [registerTools] has not been called yet.
  /// After [_onSessionReady] flushes this, it is set back to `null`.
  List<ToolDefinition>? _pendingTools;

  /// Canonical session instructions. The empty string means cleared/no
  /// instructions. This state is carried by session.open and by
  /// session.instructions.set.
  String _sessionInstructions = '';

  /// Queue of extension calls made before the session was ready.
  ///
  /// Each entry carries the extension type, payload, and a [Completer] whose
  /// [Future] was returned to the caller.  All entries are drained by
  /// [_flushPendingExtensions] after `session.ready`.
  final List<
    ({
      String extensionType,
      Map<String, dynamic> payload,
      Completer<bool> completer,
    })
  >
  _pendingExtensions = [];

  // ── Subscriptions ────────────────────────────────────────────────────────

  StreamSubscription<VhrpTransportConnectionState>? _transportStateSubscription;
  StreamSubscription<Uint8List>? _inboundSubscription;

  /// Active subscription to the live microphone input stream.
  /// Replaced on each [bindAudioInput] call; cancelled on null / dispose.
  StreamSubscription<Uint8List>? _audioInputSubscription;

  // ── Local ID counters ────────────────────────────────────────────────────

  int _msgIdCounter = 0;

  /// Monotonically increasing sequence number for [LiveAudioChunkMsg].
  /// Starts at 0; incremented before each send so wire sequences begin at 1.
  int _liveAudioSequence = 0;

  /// Secure random source for [_nextClientItemId].
  static final _random = Random.secure();

  // ─────────────────────────────────────────────────────────────────────────
  // Constructor
  // ─────────────────────────────────────────────────────────────────────────

  VhrpRealtimeAdapter({
    /// Transport used for the WebSocket connection.
    /// Defaults to [WebSocketVhrpTransport] for production; inject
    /// [FakeVhrpTransport] in tests.
    VhrpRealtimeTransport? transport,

    /// Async supplier of the JWT placed in `session.open.body.token`.
    /// Must not be null — inject a real token provider (e.g. from
    /// AuthService.getAccessToken) in production.
    required Future<String?> Function() tokenProvider,

    /// Optional URL resolver seam for testing.
    Uri Function(bool isDebugMode)? urlResolver,
  }) : _transport = transport ?? WebSocketVhrpTransport(),
       _tokenProvider = tokenProvider,
       _urlResolver = urlResolver {
    // Begin observing transport state changes immediately so the mapping
    // from VhrpTransportPhase → RealtimeAdapterConnectionPhase is always
    // up to date, even before connect() is called.
    _transportStateSubscription = _transport.connectionStateUpdates.listen(
      _onTransportState,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — State
  // ─────────────────────────────────────────────────────────────────────────

  @override
  RealtimeThread get thread => _thread;

  @override
  Stream<RealtimeThread> get threadUpdates => _threadController.stream;

  @override
  RealtimeAdapterConnectionState get connectionState => _connectionState;

  @override
  Stream<RealtimeAdapterConnectionState> get connectionStateUpdates =>
      _connectionStateController.stream;

  @override
  Stream<RealtimeAdapterError> get errors => _errorController.stream;

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens a VHRP/1 session.
  ///
  /// Flow:
  ///   1. Resolve the WebSocket URL from [AppConfig.resolveApiBaseUrl].
  ///   2. Obtain the JWT via [tokenProvider].
  ///      If `null` → emit error, transition to [failed], throw [StateError].
  ///   3. Connect the underlying transport (`vhrp.cbor.v1` subprotocol).
  ///   4. Subscribe to [inboundBytes] to start the dispatch loop.
  ///   5. Send `session.open` with model / voice / instructions / audio fmt.
  ///   6. Await `session.ready` or `session.resumed`.
  ///
  /// If [apiConfig] is not [HostedVoiceAgentApiConfig], emits an error on
  /// [errors], transitions to [failed], and throws [ArgumentError].
  @override
  Future<void> connect(VoiceAgentApiConfig apiConfig, {String? voice}) async {
    _ensureNotDisposed();

    // ── Guard: correct config type ──────────────────────────────────────────
    if (apiConfig is! HostedVoiceAgentApiConfig) {
      const code = 'adapter.wrong_config_type';
      final msg =
          'VhrpRealtimeAdapter.connect() requires HostedVoiceAgentApiConfig '
          'but received ${apiConfig.runtimeType}.';
      _emitError(RealtimeAdapterError(code: code, message: msg));
      _setConnectionState(RealtimeAdapterConnectionState.failed(message: msg));
      throw ArgumentError(msg);
    }

    // ── Step 1: URL resolution ──────────────────────────────────────────────
    final wsUri = _resolveWsUri(kDebugMode);

    // ── Step 2: Token acquisition ───────────────────────────────────────────
    final token = await _tokenProvider();
    if (token == null) {
      const code = 'auth.missing_token';
      const msg =
          'VhrpRealtimeAdapter: tokenProvider returned null. '
          'A valid JWT is required to open a VHRP session.';
      _emitError(const RealtimeAdapterError(code: code, message: msg));
      _setConnectionState(
        const RealtimeAdapterConnectionState.failed(message: msg),
      );
      // Throw so the caller receives synchronous failure feedback, mirroring
      // the contract that connect() fails fast when preconditions are unmet.
      throw StateError(msg);
    }

    // ── Step 3: Freeze connect config for reconnect loop ───────────────────
    _connectConfig = _ConnectConfig(modelId: apiConfig.modelId, voice: voice);

    // Reset reconnect counters on each fresh connect().
    _reconnectAttempt = 0;
    _isReconnecting = false;

    // ── Step 4: Transport connect ───────────────────────────────────────────
    // The _transportStateSubscription already maps transport phases to adapter
    // states, so connecting → adapter.connecting happens automatically.
    _sessionReadyCompleter = Completer<void>();

    await _transport.connect(wsUri, subprotocols: ['vhrp.cbor.v1']);

    // ── Step 5: Subscribe to inbound frames ─────────────────────────────────
    await _inboundSubscription?.cancel();
    _inboundSubscription = _transport.inboundBytes.listen(
      _onRawBytes,
      onError: _onInboundError,
    );

    // ── Step 6: Send session.open ───────────────────────────────────────────
    final audioFormat = AudioFormat(
      encoding: 'pcm_s16le',
      sampleRate: 24000,
      channels: 1,
    );

    // Reset capability extensions for this new session.
    _capabilityExtensions = const <String>[];

    final sessionOpen = SessionOpenMsg(
      messageId: _nextMsgId('session-open'),
      token: token,
      modelId: apiConfig.modelId,
      voice: voice,
      instructions: _sessionInstructions,
      audioTurnMode: _audioTurnMode == RealtimeAudioTurnMode.voiceActivity
          ? 'voice_activity'
          : 'manual',
      inputAudio: audioFormat,
      outputAudio: audioFormat,
      // resume: null — initial connect never carries resume.
      client: const <String, Object?>{},
    );

    _sendMsg(sessionOpen);

    // ── Step 7: Await session.ready / session.resumed ───────────────────────
    await _sessionReadyCompleter!.future;
  }

  /// Releases all resources.  Idempotent.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // ── Final thread snapshot probe ─────────────────────────────────────────
    // Before tearing down the transport, request the authoritative final
    // thread state from the server and log it as JSON.  This gives us a
    // complete record of the conversation at hang-up time.
    if (_connectionState.isConnected) {
      try {
        final snapshotReceived = Completer<void>();
        final sub = _threadController.stream.listen((_) {
          if (!snapshotReceived.isCompleted) snapshotReceived.complete();
        });
        _sendThreadSyncRequest('dispose');
        await snapshotReceived.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
        await sub.cancel();
      } catch (_) {
        // Best-effort; teardown must not be blocked.
      }
      _logger.info(
        'VHRP_FINAL_THREAD_JSON=${jsonEncode(_threadToJson(_thread))}',
      );
    }

    // Cancel live audio input subscription first so no more PCM is forwarded.
    await _audioInputSubscription?.cancel();
    _audioInputSubscription = null;

    await _inboundSubscription?.cancel();
    _inboundSubscription = null;

    await _transportStateSubscription?.cancel();
    _transportStateSubscription = null;

    await _transport.dispose();

    // Complete all pending request completers with an error so callers don't
    // hang forever.
    _cancelAllPendingRequests(
      StateError('VhrpRealtimeAdapter has been disposed.'),
    );

    // Complete all pending extension completers with false (session ended).
    for (final pending in _pendingExtensions) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(false);
      }
    }
    _pendingExtensions.clear();

    // Close all broadcast controllers (safe to call on already-closed ones
    // because we guard with _disposed).
    await Future.wait([
      _connectionStateController.close(),
      _errorController.close(),
      _threadController.close(),
      _assistantAudioController.close(),
      _assistantAudioCompletedController.close(),
      _userSpeakingController.close(),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — Audio I/O  (Step 6 — implemented)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Stream<Uint8List> get assistantAudioStream =>
      _assistantAudioController.stream;

  @override
  Stream<void> get assistantAudioCompleted =>
      _assistantAudioCompletedController.stream;

  @override
  bool get isUserSpeaking => _isUserSpeaking;

  @override
  Stream<bool> get isUserSpeakingUpdates => _userSpeakingController.stream;

  /// Switch between server-side VAD turn handling and client-managed one-shot
  /// turns.
  ///
  /// Sends [AudioTurnModeSetMsg] (one-way, no messageId) so the server updates
  /// its VAD pipeline immediately.  The new mode is stored in [_audioTurnMode]
  /// regardless of connection state so [bindAudioInput] gate logic stays
  /// consistent after a reconnect.
  ///
  /// Wire: `audio.turn.mode.set` with `mode` = `"voice_activity"` or
  /// `"manual"` (§4.2 of handoff doc).
  @override
  Future<void> setAudioTurnMode(RealtimeAudioTurnMode mode) async {
    _ensureNotDisposed();
    _audioTurnMode = mode;

    if (!_connectionState.isConnected) {
      // Store mode; will take effect on next connect / live send.
      return;
    }

    _sendMsg(
      AudioTurnModeSetMsg(
        mode: mode == RealtimeAudioTurnMode.voiceActivity
            ? 'voice_activity'
            : 'manual',
      ),
    );
  }

  /// Bind live PCM microphone input.
  ///
  /// • Passing a non-null [audioStream] cancels any existing subscription and
  ///   starts forwarding PCM chunks as `live.audio.chunk` messages with a
  ///   monotonically increasing [sequence] (1-based; counter incremented before
  ///   each send).
  /// • Passing `null` cancels the existing subscription without replacing it.
  /// • Re-binding (passing a new stream while one is active) cancels the
  ///   previous subscription before subscribing to the new one — no double
  ///   subscription / no leak.
  ///
  /// Live audio is forwarded unconditionally (mirroring OAI adapter behaviour):
  /// the server discards chunks received in `manual` mode.  The gate logic in
  /// [_handleLiveAudioChunk] still short-circuits on empty chunks and
  /// disconnected state.
  @override
  Future<void> bindAudioInput(Stream<Uint8List>? audioStream) async {
    _ensureNotDisposed();

    // Cancel previous subscription (re-bind or explicit null un-bind).
    await _audioInputSubscription?.cancel();
    _audioInputSubscription = null;

    if (audioStream == null) {
      return;
    }

    _audioInputSubscription = audioStream.listen(
      _handleLiveAudioChunk,
      onError: (Object error) {
        _emitError(
          RealtimeAdapterError(
            code: 'audio_input_error',
            message: 'Live audio input stream error.',
            cause: error,
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — Tool configuration  (Step 7 — implemented)
  // ─────────────────────────────────────────────────────────────────────────

  /// Replaces the server-side tool catalog for this session.
  ///
  /// Wire: `tools.set` with a `tools` array (each entry:
  ///   `{name, description, parameters}`).  An empty list disables tools.
  ///
  /// If the session is not yet connected, the list is buffered (last-write-wins)
  /// and automatically sent as `tools.set` once `session.ready` is received
  /// (handoff doc §7.1).
  ///
  /// If the session is connected, sends immediately and awaits the `ack`.
  @override
  Future<void> registerTools(List<ToolDefinition> tools) async {
    _ensureNotDisposed();

    if (!_connectionState.isConnected) {
      // Buffer: last-write-wins; flushed in _onSessionReady.
      _pendingTools = List<ToolDefinition>.unmodifiable(tools);
      return;
    }

    await _sendToolsSet(tools);
  }

  /// Updates the session-level system instructions.
  ///
  /// Wire: `session.instructions.set` with the canonical non-null instructions
  /// string. The empty string clears instructions.
  ///
  /// Pre-connect behaviour: the canonical value is stored in
  /// [_sessionInstructions] and carried by `session.open`.
  @override
  Future<void> setInstructions(String instructions) async {
    _ensureNotDisposed();

    final normalised = instructions.trim();
    final nextInstructions = normalised.isEmpty ? '' : normalised;
    if (_sessionInstructions == nextInstructions) {
      return;
    }

    _sessionInstructions = nextInstructions;

    if (!_connectionState.isConnected) {
      return;
    }

    await _sendInstructionsSet(_sessionInstructions);
  }

  /// Applies a provider-specific session extension.
  ///
  /// Wire: `session.extension.apply` with `extensionType` / `payload`.
  ///
  /// Returns `true` when the server acknowledges the extension (`ack`);
  /// `false` when the server rejects it (`error(extension.unsupported)`),
  /// or when the key is not in `session.ready.capabilities.extensions`.
  ///
  /// Pre-connect behaviour: the call is buffered; the returned [Future] resolves
  /// after the post-ready round-trip completes (handoff doc §7.1, §7.2).
  @override
  Future<bool> applyProviderExtension(
    String extensionType,
    Map<String, dynamic> payload,
  ) async {
    _ensureNotDisposed();

    if (!_connectionState.isConnected) {
      // Buffer: resolved after session.ready + ack/error round-trip.
      final completer = Completer<bool>();
      _pendingExtensions.add((
        extensionType: extensionType,
        payload: payload,
        completer: completer,
      ));
      return completer.future;
    }

    return _sendExtensionApply(extensionType, payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — User content  (Step 5 — implemented)
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a one-shot audio turn (manual mode).
  ///
  /// Wire: [TurnAudioSubmitMsg] — pcm as CBOR bstr (raw bytes, not base64),
  /// sampleRate=24000, channels=1, bitDepth=16.
  ///
  /// The thread is updated when the server echoes back a canonical `add_item`
  /// via `thread.patch`.
  @override
  Future<String> sendAudioOneShot(Uint8List audioBytes) async {
    _ensureNotDisposed();
    _ensureConnected();

    final clientItemId = _nextClientItemId();

    // Send turn.audio.submit — pcm is CBOR bstr (raw bytes, never base64).
    _sendMsg(
      TurnAudioSubmitMsg(
        messageId: _nextMsgId('aud'),
        clientItemId: clientItemId,
        pcm: audioBytes,
        sampleRate: 24000,
        channels: 1,
        bitDepth: 16,
      ),
    );

    return clientItemId;
  }

  /// Send a text message from the user.
  ///
  /// Wire: [TurnTextSubmitMsg] with clientItemId, text, and messageId.
  ///
  /// A local user message item is staged immediately so callers get a stable
  /// handle before the server echo. The later canonical `add_item` from
  /// `thread.patch` merges onto the same clientItemId.
  @override
  Future<String> sendText(String text) async {
    _ensureNotDisposed();
    _ensureConnected();

    final clientItemId = _nextClientItemId();

    _thread.addItem(
      RealtimeThreadItem(
        id: clientItemId,
        type: RealtimeThreadItemType.message,
        role: RealtimeThreadItemRole.user,
        status: RealtimeThreadItemStatus.inProgress,
        content: <RealtimeThreadContentPart>[RealtimeThreadTextPart()],
      ),
    );
    _emitThreadUpdate();

    // Send turn.text.submit over CBOR transport.
    _sendMsg(
      TurnTextSubmitMsg(
        messageId: _nextMsgId('txt'),
        clientItemId: clientItemId,
        text: text,
      ),
    );

    return clientItemId;
  }

  /// Send an image from the user.
  ///
  /// Wire: [TurnImageSubmitMsg] — imageBytes as CBOR bstr (raw bytes, not base64).
  ///
  /// The thread is updated when the server echoes back a canonical `add_item`
  /// via `thread.patch`.
  @override
  Future<String> sendImage(Uint8List imageBytes) async {
    _ensureNotDisposed();
    _ensureConnected();

    final clientItemId = _nextClientItemId();

    // Send turn.image.submit — imageBytes is CBOR bstr (raw bytes, never base64).
    _sendMsg(
      TurnImageSubmitMsg(
        messageId: _nextMsgId('img'),
        clientItemId: clientItemId,
        imageBytes: imageBytes,
      ),
    );

    return clientItemId;
  }

  /// Return the result of a tool call the model requested.
  ///
  /// Wire: [ToolResultSubmitMsg] with clientItemId, callId, output, disposition
  /// (enum → name string), errorMessage (omitted when null).
  ///
  /// A local functionCallOutput item is staged immediately so callers can track
  /// the submitted result without waiting for the server echo.  The later
  /// canonical `add_item` from `thread.patch` merges onto the same clientItemId.
  @override
  Future<String> sendFunctionOutput({
    required String callId,
    required String output,
    RealtimeToolOutputDisposition disposition =
        RealtimeToolOutputDisposition.success,
    String? errorMessage,
  }) async {
    _ensureNotDisposed();
    _ensureConnected();

    final clientItemId = _nextClientItemId();

    _thread.addItem(
      RealtimeThreadItem(
        id: clientItemId,
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

    // Send tool.result.submit — output is opaque UTF-8 (not necessarily JSON).
    _sendMsg(
      ToolResultSubmitMsg(
        messageId: _nextMsgId('tool'),
        clientItemId: clientItemId,
        callId: callId,
        output: output,
        disposition: disposition.name, // 'success' | 'error'
        errorMessage: errorMessage,
      ),
    );

    return clientItemId;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RealtimeAdapter — Response control  (Step 8)
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends `assistant.interrupt` with `reason:"barge_in"` to stop the current
  /// generation.
  ///
  /// Wire: one-way `assistant.interrupt` (§4.11) — no messageId, no ack.
  ///
  /// Local state: [isUserSpeaking] is NOT changed here (VAD-driven state).
  /// The server owns interrupt projection: it resolves completed pending tool
  /// calls with cancellation/error outputs, marks unfinished function calls
  /// incomplete, and emits the resulting `thread.patch` ops for the projector.
  @override
  Future<void> interrupt() async {
    _ensureNotDisposed();

    if (!_connectionState.isConnected) {
      // Not connected — nothing to interrupt; silently ignore.
      return;
    }

    _sendMsg(AssistantInterruptMsg(reason: 'barge_in'));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Transport state → adapter state mapping  (§6.2)
  // ─────────────────────────────────────────────────────────────────────────

  void _onTransportState(VhrpTransportConnectionState state) {
    switch (state.phase) {
      case VhrpTransportPhase.idle:
        _setConnectionState(const RealtimeAdapterConnectionState.idle());

      case VhrpTransportPhase.connecting:
        _setConnectionState(const RealtimeAdapterConnectionState.connecting());

      case VhrpTransportPhase.connected:
        // The transport is up but VHRP session negotiation is still pending
        // (we haven't received session.ready yet).  Keep adapter at
        // "connecting" — the transition to "connected" is driven by the
        // session.ready handler below.
        _setConnectionState(const RealtimeAdapterConnectionState.connecting());

      case VhrpTransportPhase.disconnecting:
        _setConnectionState(
          const RealtimeAdapterConnectionState.disconnecting(),
        );

      case VhrpTransportPhase.disconnected:
        _setConnectionState(
          RealtimeAdapterConnectionState.disconnected(message: state.message),
        );
        _failSessionReadyCompleterIfPending(
          Exception(
            state.message ?? 'Transport disconnected before session.ready.',
          ),
        );
        _cancelAllPendingRequests(
          Exception(
            state.message ??
                'Transport disconnected; pending requests aborted.',
          ),
        );
        // ── Step 8: auto-reconnect on unexpected disconnect ─────────────────
        // Trigger reconnect only when we had an established session (sessionId
        // is set) and are not already reconnecting and not being disposed.
        if (_sessionId != null && !_isReconnecting && !_disposed) {
          _startReconnectLoop();
        }

      case VhrpTransportPhase.failed:
        _setConnectionState(
          RealtimeAdapterConnectionState.failed(
            message: state.message,
            error: state.error,
          ),
        );
        _failSessionReadyCompleterIfPending(
          state.error ??
              Exception(
                state.message ?? 'Transport failed before session.ready.',
              ),
        );
        _cancelAllPendingRequests(
          state.error ??
              Exception(
                state.message ?? 'Transport failed; pending requests aborted.',
              ),
        );
        // ── Step 8: auto-reconnect on transport failure ─────────────────────
        if (_sessionId != null && !_isReconnecting && !_disposed) {
          _startReconnectLoop();
        }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Inbound dispatch loop
  // ─────────────────────────────────────────────────────────────────────────

  void _onRawBytes(Uint8List bytes) {
    final VhrpS2cMessage msg;
    try {
      msg = _codec.decode(bytes);
      if (kDebugMode) {
        _logger.info(
          '[DIAG-VHRP-IN] frameBytes=${bytes.length} '
          '${VhrpDebugFormat.formatS2c(msg)}',
        );
      }
    } catch (e) {
      _emitError(
        RealtimeAdapterError(
          code: 'codec.decode_error',
          message: 'Failed to decode inbound VHRP frame: $e',
          cause: e,
        ),
      );
      return;
    }
    _dispatchMessage(msg);
  }

  void _onInboundError(Object error, [StackTrace? _]) {
    _emitError(
      RealtimeAdapterError(
        code: 'transport.stream_error',
        message: 'Inbound stream error: $error',
        cause: error,
      ),
    );
  }

  /// Routes decoded S2C messages to their handlers.
  ///
  /// Step 3 handles: session.ready, session.resumed, error.
  /// All other types are left as TODO stubs for subsequent steps.
  void _dispatchMessage(VhrpS2cMessage msg) {
    switch (msg) {
      case SessionReadyMsg m:
        _onSessionReady(m);

      case SessionResumedMsg m:
        _onSessionResumed(m);

      case ErrorMsg m:
        _onErrorMsg(m);

      // ── Step 4: thread projection ─────────────────────────────────────────
      case ThreadSnapshotMsg m:
        _onThreadSnapshot(m);

      case ThreadPatchMsg m:
        _onThreadPatch(m);

      // ── Step 6: audio I/O and VAD ─────────────────────────────────────────
      case AssistantAudioChunkMsg m:
        _onAssistantAudioChunk(m);

      case AssistantAudioDoneMsg _:
        _onAssistantAudioDone();

      case VadStateMsg m:
        _setUserSpeaking(m.isSpeaking);

      // ── Step 7: ack / error correlation ──────────────────────────────────
      case AckMsg m:
        _onAckMsg(m);

      case UnknownTypeS2cMsg _:
        // Forward-compatibility: unknown types are silently ignored per spec.
        // Log if needed; do not trigger recovery here.
        break;
    }
  }

  // ── thread.snapshot ────────────────────────────────────────────────────────

  void _onThreadSnapshot(ThreadSnapshotMsg msg) {
    // Replace the local thread wholesale (§5.4 — snapshot is authoritative).
    _thread = _projector.applySnapshot(msg);
    // Keep the stored IDs in sync with the snapshot (may differ from
    // session.ready values on resume + resync).
    _threadId = _thread.id;
    _conversationId = _thread.conversationId;

    _emitThreadUpdate();
  }

  // ── thread.patch ────────────────────────────────────────────────────────────

  void _onThreadPatch(ThreadPatchMsg msg) {
    final result = _projector.applyPatch(msg, _thread);

    if (result.desync) {
      // One or more ops could not be applied — request a fresh snapshot (§5.5,
      // §6).  This is a best-effort fire-and-forget; reconnect loop (Step 8)
      // handles deeper failure scenarios.
      _emitError(
        RealtimeAdapterError(
          code: 'thread.desync',
          message:
              result.desyncReason ??
              'thread.patch could not be applied; requesting resync.',
        ),
      );
      _sendThreadSyncRequest('patch_apply_failed');
      return;
    }
    _emitThreadUpdate();
  }

  /// Sends a `thread.sync.request` to the server requesting a full snapshot.
  void _sendThreadSyncRequest(String reason) {
    try {
      _sendMsg(
        ThreadSyncRequestMsg(
          messageId: _nextMsgId('thread-sync'),
          reason: reason,
        ),
      );
    } catch (_) {
      // If the transport is already closed/disconnected, the send will throw
      // a StateError.  Ignore — the reconnect path (Step 8) will re-request.
    }
  }

  // ── session.ready ──────────────────────────────────────────────────────────

  void _onSessionReady(SessionReadyMsg msg) {
    _sessionId = msg.sessionId;
    _threadId = msg.threadId;
    _conversationId = msg.conversationId;

    // Store server-advertised extension capabilities.
    _capabilityExtensions = List<String>.unmodifiable(msg.capabilityExtensions);

    _setConnectionState(const RealtimeAdapterConnectionState.connected());

    // Flush pre-connect buffers before completing the completer so that the
    // adapter is fully configured by the time connect() returns.
    _flushPreConnectBuffers();

    _sessionReadyCompleter?.complete();
    _sessionReadyCompleter = null;
  }

  // ── session.resumed ────────────────────────────────────────────────────────

  /// Handles a successful resume (reconnect) response.
  ///
  /// Per §6.1 step 4: after receiving `session.resumed`, the adapter MUST send
  /// `thread.sync.request("reconnected")`.  The server will reply with a full
  /// `thread.snapshot` which [_onThreadSnapshot] will apply.
  ///
  /// Session state (tools / instructions / extensions) is NOT re-sent: the
  /// server preserved the session server-side, so the prior state is intact.
  /// Only the thread projection needs to be refreshed via the snapshot.
  ///
  /// [_liveAudioSequence] is reset to 0 so the new session starts fresh
  /// sequence numbering, preventing the server from seeing a gap.
  void _onSessionResumed(SessionResumedMsg msg) {
    _sessionId = msg.sessionId;
    _threadId = msg.threadId;
    _conversationId = msg.conversationId;

    // Reset live audio sequence so the resumed session starts from 1 again.
    _liveAudioSequence = 0;

    // Reset reconnect counter: the reconnect succeeded.
    _reconnectAttempt = 0;
    _isReconnecting = false;

    _setConnectionState(const RealtimeAdapterConnectionState.connected());

    // Complete the completer used by the reconnect loop (not connect()).
    _sessionReadyCompleter?.complete();
    _sessionReadyCompleter = null;

    // Step §6.1-4: request the full thread snapshot.
    _sendThreadSyncRequest('reconnected');
  }

  // ── ack ────────────────────────────────────────────────────────────────────

  /// Resolves the pending [Completer] registered under [AckMsg.replyTo].
  void _onAckMsg(AckMsg msg) {
    final replyTo = msg.replyTo;
    if (replyTo == null) return;
    final completer = _pendingRequests.remove(replyTo);
    if (completer != null && !completer.isCompleted) {
      completer.complete(msg);
    }
  }

  // ── error ──────────────────────────────────────────────────────────────────

  void _onErrorMsg(ErrorMsg msg) {
    // ── Correlation: if replyTo matches a pending request, fail that completer
    //    rather than (only) emitting a global error.  This lets individual
    //    awaiting callers handle the failure inline.
    final replyTo = msg.replyTo;
    if (replyTo != null) {
      final completer = _pendingRequests.remove(replyTo);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          RealtimeAdapterError(
            code: msg.code,
            message: msg.message,
            cause: msg,
          ),
        );
        // For recoverable correlated errors we still surface them globally so
        // the app's error stream is complete.
        _emitError(
          RealtimeAdapterError(
            code: msg.code,
            message: msg.message,
            cause: msg,
          ),
        );
        if (!msg.recoverable) {
          _setConnectionState(
            RealtimeAdapterConnectionState.failed(
              message: '[${msg.code}] ${msg.message}',
            ),
          );
          _failSessionReadyCompleterIfPending(
            Exception(
              'Non-recoverable VHRP error: ${msg.code}: ${msg.message}',
            ),
          );
        }
        return;
      }
    }

    // No correlation — emit as a general error.
    _emitError(
      RealtimeAdapterError(code: msg.code, message: msg.message, cause: msg),
    );

    if (!msg.recoverable) {
      // Non-recoverable errors immediately terminate the session (the server
      // closes the WebSocket after sending this frame).
      _setConnectionState(
        RealtimeAdapterConnectionState.failed(
          message: '[${msg.code}] ${msg.message}',
        ),
      );
      _failSessionReadyCompleterIfPending(
        Exception('Non-recoverable VHRP error: ${msg.code}: ${msg.message}'),
      );
    } else if (msg.code == 'resume.not_available') {
      // resume.not_available is recoverable — the server keeps the connection
      // open.  But the reconnect loop is waiting on _sessionReadyCompleter for
      // a session.ready / session.resumed reply.  We need to fail that
      // completer with a typed error so the loop can detect the code and
      // branch to the fresh session.open fallback (§6.1).
      final c = _sessionReadyCompleter;
      if (c != null && !c.isCompleted) {
        c.completeError(
          RealtimeAdapterError(
            code: msg.code,
            message: msg.message,
            cause: msg,
          ),
        );
        _sessionReadyCompleter = null;
      }
    }
    // Other recoverable errors are surfaced on [errors] only; session continues.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  // ── assistant.audio.chunk ─────────────────────────────────────────────────

  /// Handles one inbound assistant PCM chunk.
  ///
  /// Dual-path (Strong constraint / handoff doc §5.6 + §10.2):
  ///   1. Playback path  — [pcm] (raw [Uint8List]) is pushed directly onto
  ///      [assistantAudioStream].  No base64 decode is performed because the
  ///      CBOR codec already surfaces the byte-string as [Uint8List].
  ///   2. Accumulation path — [pcm] is base64-encoded and appended to the
  ///      [RealtimeThreadAudioPart.audioChunks] list of the corresponding
  ///      content part so that callers can reconstruct the full audio later.
  ///
  /// If the target item or audio part has not yet been created by the
  /// projector (via `put_part`), the accumulation step is silently skipped.
  /// The playback stream is always updated regardless.
  void _onAssistantAudioChunk(AssistantAudioChunkMsg msg) {
    // ── 1. Playback: raw bytes straight to the stream ────────────────────────
    if (!_assistantAudioController.isClosed) {
      _assistantAudioController.add(msg.pcm);
    }

    // ── 2. Accumulation: base64-encode and append to thread audio part ───────
    final item = _thread.findItem(msg.itemId);
    if (item == null) {
      // Item not yet in thread (race between put_part and audio chunk).
      // Silently skip accumulation — playback is unaffected.
      return;
    }

    final part = item.findContentPart(msg.contentIndex);
    final audioPart = part is RealtimeThreadAudioPart ? part : null;
    if (audioPart == null) {
      // Part not yet created or wrong type — skip accumulation safely.
      return;
    }

    audioPart.appendAudioDelta(base64Encode(msg.pcm));
    _emitThreadUpdate();
  }

  // ── assistant.audio.done ─────────────────────────────────────────────────

  /// Fires [assistantAudioCompleted] to signal the audio response boundary.
  ///
  /// This is distinct from item completion: the item status is intentionally
  /// NOT changed here (handoff doc §5.7).  `set_status` ops from the server
  /// via `thread.patch` are the only authoritative source of item status.
  void _onAssistantAudioDone() {
    if (!_assistantAudioCompletedController.isClosed) {
      _assistantAudioCompletedController.add(null);
    }
  }

  // ── VAD state ─────────────────────────────────────────────────────────────

  /// Updates [isUserSpeaking] and emits on [isUserSpeakingUpdates].
  ///
  /// Deduplicated: identical consecutive values are dropped, matching the
  /// OAI adapter pattern.
  void _setUserSpeaking(bool value) {
    if (_isUserSpeaking == value) return;
    _isUserSpeaking = value;
    if (!_userSpeakingController.isClosed) {
      _userSpeakingController.add(value);
    }
  }

  // ── Live audio input ──────────────────────────────────────────────────────

  /// Forwards one live microphone PCM chunk as a `live.audio.chunk` message.
  ///
  /// Short-circuits if:
  ///   - [bytes] is empty (nothing to send).
  ///   - The adapter is not in the [connected] state (transport would reject).
  ///   - The current turn mode is [manual] (OAI parity — server discards live
  ///     audio in manual mode; suppress at the client to avoid wasteful sends).
  ///
  /// The [_liveAudioSequence] counter is incremented before each send so wire
  /// sequences start at 1 and are strictly monotonic within a session.
  void _handleLiveAudioChunk(Uint8List bytes) {
    if (bytes.isEmpty || !_connectionState.isConnected) return;
    if (_audioTurnMode != RealtimeAudioTurnMode.voiceActivity) return;

    _liveAudioSequence += 1;
    _sendMsg(LiveAudioChunkMsg(pcm: bytes, sequence: _liveAudioSequence));
  }

  void _emitThreadUpdate() {
    if (!_threadController.isClosed) {
      _threadController.add(_thread);
    }
  }

  void _setConnectionState(RealtimeAdapterConnectionState state) {
    _connectionState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  void _emitError(RealtimeAdapterError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  // ── Pre-connect buffer flush ──────────────────────────────────────────────

  /// Sends all buffered tools/instructions/extensions that were enqueued before
  /// `session.ready`.  Called from [_onSessionReady] while the adapter is
  /// already in the [connected] state.
  ///
  /// Order: tools.set → session.instructions.set → session.extension.apply
  /// (one extension at a time, each awaiting its ack before the next).
  void _flushPreConnectBuffers() {
    // Use unawaited fire-and-forget with error capture so individual flush
    // failures don't crash the zone; they surface on the errors stream instead.
    _doFlushPreConnectBuffers().catchError((Object e) {
      _emitError(
        RealtimeAdapterError(
          code: 'flush.error',
          message: 'Error flushing pre-connect buffers: $e',
          cause: e,
        ),
      );
    });
  }

  Future<void> _doFlushPreConnectBuffers() async {
    // 1. Tools (last-write-wins list, or empty list disables).
    final tools = _pendingTools;
    _pendingTools = null;
    if (tools != null) {
      await _sendToolsSet(tools);
    }

    // 2. Instructions are not flushed here: [setInstructions] owns the
    // canonical state and [connect] carries that state in session.open.

    // 3. Extensions (FIFO queue; each extension awaits its ack/error before
    //    the next one is sent, maintaining order).
    final extensions = List.of(_pendingExtensions);
    _pendingExtensions.clear();
    for (final pending in extensions) {
      if (pending.completer.isCompleted) continue;
      try {
        final result = await _sendExtensionApply(
          pending.extensionType,
          pending.payload,
        );
        if (!pending.completer.isCompleted) {
          pending.completer.complete(result);
        }
      } catch (_) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete(false);
        }
      }
    }
  }

  // ── Thread JSON serialization (probe/debug) ───────────────────────────────

  /// Converts [thread] to a plain JSON-serializable map.
  ///
  /// Audio chunks are replaced with a byte-count summary to keep the log line
  /// short.  All other text content is included verbatim.
  Map<String, Object?> _threadToJson(RealtimeThread thread) {
    return {
      'id': thread.id,
      'conversationId': thread.conversationId,
      'items': thread.items.map((item) {
        return {
          'id': item.id,
          'type': item.type.name,
          'role': item.role?.name,
          'status': item.status.wireValue,
          'callId': item.callId,
          'name': item.name,
          'arguments': item.arguments,
          'output': item.output,
          'toolOutputDisposition': item.toolOutputDisposition?.name,
          'toolErrorMessage': item.toolErrorMessage,
          'content': item.content.map((part) {
            if (part is RealtimeThreadTextPart) {
              return {'type': 'text', 'text': part.text, 'isDone': part.isDone};
            } else if (part is RealtimeThreadAudioPart) {
              return {
                'type': 'audio',
                'transcript': part.transcript,
                'audioChunks': '<${part.audioChunks.length} chunks>',
                'isDone': part.isDone,
              };
            } else if (part is RealtimeThreadImagePart) {
              return {
                'type': 'image',
                'imageUrl': part.imageUrl,
                'detail': part.detail,
                'isDone': part.isDone,
              };
            } else {
              return {'type': part.type, 'isDone': part.isDone};
            }
          }).toList(),
        };
      }).toList(),
    };
  }

  // ── Wire send helpers ─────────────────────────────────────────────────────

  /// Encodes [message] and sends it via the transport.
  ///
  /// In debug mode this also emits a human-readable tx log line via the
  /// [_logger] at FINE level.  Production builds are not affected because the
  /// format string is never evaluated when [kDebugMode] is false.
  void _sendMsg(VhrpC2sMessage message) {
    final bytes = _codec.encode(message);
    if (kDebugMode) {
      _logger.info(
        '[DIAG-VHRP-OUT] frameBytes=${bytes.length} '
        '${VhrpDebugFormat.formatC2s(message)}',
      );
    }
    _transport.sendBytes(bytes);
  }

  /// Sends `tools.set` and awaits the server ack.
  ///
  /// [ToolDefinition] → [ToolSpec] mapping:
  ///   - `name`        = [ToolDefinition.toolKey]
  ///   - `description` = [ToolDefinition.description]
  ///   - `parameters`  = [ToolDefinition.parametersSchema]
  ///
  /// This mirrors [ToolDefinition.toRealtimeJson()] (used by the OAI adapter)
  /// but adapted to the [ToolSpec] type used by [ToolsSetMsg].
  Future<void> _sendToolsSet(List<ToolDefinition> tools) async {
    final msgId = _nextMsgId('tools-set');
    final completer = Completer<AckMsg>();
    _pendingRequests[msgId] = completer;

    _sendMsg(
      ToolsSetMsg(
        messageId: msgId,
        tools: tools
            .map(
              (t) => ToolSpec(
                name: t.toolKey,
                description: t.description,
                parameters: Map<String, Object?>.from(
                  t.realtimeParametersSchema,
                ),
              ),
            )
            .toList(),
      ),
    );

    await completer.future; // throws on error; caller propagates
  }

  /// Sends `session.instructions.set` and awaits the server ack.
  Future<void> _sendInstructionsSet(String instructions) async {
    final msgId = _nextMsgId('instr-set');
    final completer = Completer<AckMsg>();
    _pendingRequests[msgId] = completer;

    _sendMsg(
      SessionInstructionsSetMsg(messageId: msgId, instructions: instructions),
    );

    await completer.future;
  }

  /// Sends `session.extension.apply` and resolves to `true` (ack) or `false`
  /// (error with code `extension.unsupported`).
  ///
  /// Guard: if [extensionType] is not in [_capabilityExtensions] (populated
  /// from `session.ready`), returns `false` immediately without a round-trip.
  /// This matches the intent of handoff doc §7.2 ("safe" approach: don't waste
  /// a round-trip for a key the server already told us it doesn't support).
  ///
  /// Note: [RealtimeProviderExtensions] constants are imported to document the
  /// 4 valid extension keys; no other keys are valid in this adapter.
  Future<bool> _sendExtensionApply(
    String extensionType,
    Map<String, dynamic> payload,
  ) async {
    // Capability guard: server told us during session.ready which extensions
    // it supports.  Absent key → false without a wire round-trip.
    if (_capabilityExtensions.isNotEmpty &&
        !_capabilityExtensions.contains(extensionType)) {
      return false;
    }

    final msgId = _nextMsgId('ext-apply');
    final completer = Completer<AckMsg>();
    _pendingRequests[msgId] = completer;

    _sendMsg(
      SessionExtensionApplyMsg(
        messageId: msgId,
        extensionType: extensionType,
        payload: Map<String, Object?>.from(payload),
      ),
    );

    try {
      await completer.future;
      return true; // ack received
    } on RealtimeAdapterError catch (e) {
      // error(extension.unsupported) → false; any other error also → false
      // (server explicitly refused, safe to propagate as false).
      if (e.code == 'extension.unsupported') {
        return false;
      }
      // Re-throw unexpected errors (e.g. non-recoverable session errors).
      rethrow;
    }
  }

  /// Completes all open [_pendingRequests] completers with [error] and clears
  /// the map.  Called from [dispose] and on non-recoverable transport failures.
  void _cancelAllPendingRequests(Object error) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingRequests.clear();
  }

  void _failSessionReadyCompleterIfPending(Object error) {
    final c = _sessionReadyCompleter;
    if (c != null && !c.isCompleted) {
      c.completeError(error);
    }
    _sessionReadyCompleter = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 8: Reconnect loop helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns `true` if the item identified by [itemId] or [callId] has been
  /// Starts the automatic reconnect loop in the background.
  ///
  /// Design:
  ///   • Guards against concurrent loops via [_isReconnecting].
  ///   • Stops if [_disposed] or if [_connectConfig] is null.
  ///   • Exponential backoff: `500 ms × 2^attempt`, capped at 16 s.
  ///   • Up to [_maxReconnectAttempts] consecutive attempts; gives up after
  ///     that and transitions to [failed].
  ///
  /// Resume strategy (§6.1):
  ///   1. Try `session.open` with `resume: { sessionId: _sessionId }`.
  ///   2. If `session.resumed` → send `thread.sync.request("reconnected")`.
  ///      `_onSessionResumed` handles steps 4-5 (thread snapshot replacement).
  ///   3. If `error(resume.not_available)` → fall back to new `session.open`
  ///      (no `resume` field), repopulate pre-connect buffers.
  ///
  /// Tools / instructions / extensions re-send policy:
  ///   • Resume path: NOT re-sent.  The server preserved the session.
  ///   • New session path (resume.not_available): pre-connect buffers are
  ///     repopulated from [_persistedTools] / [_persistedInstructions] so
  ///     that [_flushPreConnectBuffers] restores them on session.ready.
  ///     NOTE: This adapter does not yet persist tools/instructions between
  ///     reconnects (out of scope for step 8; tracked as a follow-up).
  ///     For now the new session starts without tools/instructions — callers
  ///     are expected to call [registerTools]/[setInstructions] again if they
  ///     observe a new `session.ready` (not `session.resumed`).
  void _startReconnectLoop() {
    _isReconnecting = true;
    _doReconnectLoop().catchError((Object e) {
      _isReconnecting = false;
      if (!_disposed) {
        _emitError(
          RealtimeAdapterError(
            code: 'reconnect.failed',
            message: 'Reconnect loop terminated with error: $e',
            cause: e,
          ),
        );
        _setConnectionState(
          RealtimeAdapterConnectionState.failed(
            message: 'Reconnect loop terminated: $e',
            error: e,
          ),
        );
      }
    });
  }

  Future<void> _doReconnectLoop() async {
    final config = _connectConfig;
    if (config == null || _disposed) {
      _isReconnecting = false;
      return;
    }

    while (!_disposed && _reconnectAttempt < _maxReconnectAttempts) {
      // Exponential backoff before each attempt (including the first — give
      // the network a moment to recover after an unexpected disconnect).
      final delayMs = (_reconnectBaseMs * (1 << _reconnectAttempt)).clamp(
        0,
        _reconnectMaxMs,
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));

      if (_disposed) break;

      _reconnectAttempt += 1;
      _setConnectionState(const RealtimeAdapterConnectionState.connecting());

      // Acquire a fresh JWT for the reconnect session.open.
      String? token;
      try {
        token = await _tokenProvider();
      } catch (_) {
        token = null;
      }

      if (_disposed) break;

      if (token == null) {
        // Cannot reconnect without a valid token — give up immediately.
        _isReconnecting = false;
        _setConnectionState(
          const RealtimeAdapterConnectionState.failed(
            message: 'Reconnect aborted: tokenProvider returned null.',
          ),
        );
        return;
      }

      // Open a new WebSocket connection.
      try {
        await _transport.connect(
          _resolveWsUri(kDebugMode),
          subprotocols: ['vhrp.cbor.v1'],
        );
      } catch (e) {
        // Transport connect threw — loop to next attempt.
        continue;
      }

      if (_disposed) break;

      // Re-subscribe to inbound bytes on the new connection.
      await _inboundSubscription?.cancel();
      _inboundSubscription = _transport.inboundBytes.listen(
        _onRawBytes,
        onError: _onInboundError,
      );

      // Build session.open WITH resume request (§6.1 step 2).
      final sessionIdForResume = _sessionId;
      _sessionReadyCompleter = Completer<void>();

      final audioFormat = AudioFormat(
        encoding: 'pcm_s16le',
        sampleRate: 24000,
        channels: 1,
      );

      final sessionOpen = SessionOpenMsg(
        messageId: _nextMsgId('session-open-resume'),
        token: token,
        modelId: config.modelId,
        voice: config.voice,
        instructions: _sessionInstructions,
        audioTurnMode: _audioTurnMode == RealtimeAudioTurnMode.voiceActivity
            ? 'voice_activity'
            : 'manual',
        inputAudio: audioFormat,
        outputAudio: audioFormat,
        resume: sessionIdForResume != null
            ? ResumeRequest(sessionId: sessionIdForResume)
            : null,
        client: const <String, Object?>{},
      );

      try {
        _sendMsg(sessionOpen);
      } catch (_) {
        // Transport already closed — loop to next attempt.
        _sessionReadyCompleter?.completeError(
          StateError('Transport closed before session.open could be sent.'),
        );
        _sessionReadyCompleter = null;
        continue;
      }

      // Wait for session.resumed / session.ready / error.
      // The completer is resolved by _onSessionResumed / _onSessionReady.
      // It is failed by _failSessionReadyCompleterIfPending (called from
      // _onTransportState on disconnect/failed) or by _onErrorMsg for
      // non-recoverable errors.
      //
      // Special case: error(resume.not_available) is handled inline here
      // because the error handler fails the completer with the error object.
      bool resumeNotAvailable = false;
      try {
        await _sessionReadyCompleter!.future;
        // Success — _onSessionResumed or _onSessionReady completed the future.
        // State transitions and thread.sync.request already sent by the handler.
        _isReconnecting = false;
        return;
      } on RealtimeAdapterError catch (e) {
        if (e.code == 'resume.not_available') {
          resumeNotAvailable = true;
        } else {
          // Some other correlated error — treat as a transient failure and
          // retry the loop.
          continue;
        }
      } catch (_) {
        // Transport disconnect or other error — retry.
        continue;
      } finally {
        _sessionReadyCompleter = null;
      }

      if (_disposed) break;

      // ── resume.not_available fallback (§6.1): fresh session.open ────────
      if (resumeNotAvailable) {
        // The server no longer holds our session.  Open a new WebSocket and
        // start a fresh session without a `resume` field.
        //
        // The current WebSocket may still be open (the server sent a
        // recoverable error).  We reuse the existing connection here and
        // simply send a new session.open without `resume`.
        //
        // Reset capability extensions — the new session will advertise fresh
        // capabilities in its session.ready.
        _capabilityExtensions = const <String>[];
        _sessionReadyCompleter = Completer<void>();

        final freshOpen = SessionOpenMsg(
          messageId: _nextMsgId('session-open-fresh'),
          token: token,
          modelId: config.modelId,
          voice: config.voice,
          instructions: _sessionInstructions,
          audioTurnMode: _audioTurnMode == RealtimeAudioTurnMode.voiceActivity
              ? 'voice_activity'
              : 'manual',
          inputAudio: audioFormat,
          outputAudio: audioFormat,
          // resume: null — fresh session, no resume.
          client: const <String, Object?>{},
        );

        try {
          _sendMsg(freshOpen);
        } catch (_) {
          _sessionReadyCompleter?.completeError(
            StateError(
              'Transport closed before fresh session.open could be sent.',
            ),
          );
          _sessionReadyCompleter = null;
          continue;
        }

        try {
          await _sessionReadyCompleter!.future;
          // Fresh session.ready received; _onSessionReady flushed buffers.
          _isReconnecting = false;
          return;
        } catch (_) {
          // Fresh session also failed — retry the whole loop.
          continue;
        } finally {
          _sessionReadyCompleter = null;
        }
      }
    }

    // Exhausted all attempts.
    _isReconnecting = false;
    if (!_disposed) {
      const msg = 'Reconnect loop exhausted all attempts.';
      _emitError(
        const RealtimeAdapterError(code: 'reconnect.exhausted', message: msg),
      );
      _setConnectionState(
        const RealtimeAdapterConnectionState.failed(message: msg),
      );
    }
  }

  /// Resolves the WebSocket [Uri] to connect to.
  ///
  /// Uses [_urlResolver] when injected (test seam), otherwise calls
  /// [AppConfig.resolveApiBaseUrl] (synchronous, returns [String]) and
  /// rewrites the scheme (https→wss, http→ws) and appends the VHRP path.
  Uri _resolveWsUri(bool isDebugMode) {
    if (_urlResolver != null) {
      return _urlResolver(isDebugMode);
    }

    final baseStr = AppConfig.resolveApiBaseUrl(isDebugMode: isDebugMode);
    final base = Uri.parse(baseStr);

    // Scheme rewrite: https → wss, http → ws (or anything else → ws).
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';

    // Path construction: base already ends with '/api', we append the suffix.
    // E.g. 'http://localhost:8080/api' → path = '/api'
    //      final path = '/api/hosted-realtime/v1/connect'
    final rawPath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    const vhrpPath = '/hosted-realtime/v1/connect';

    return base.replace(scheme: wsScheme, path: '$rawPath$vhrpPath');
  }

  /// Generates a unique client item ID.
  ///
  /// Format: `ci-<timestamp_us>-<8 hex random chars>` — always ASCII,
  /// length ≤ 33 chars (well within the 1–64 char constraint of §3.4).
  /// The microsecond timestamp + cryptographic random suffix provides
  /// practical uniqueness without an external UUID package.
  String _nextClientItemId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return 'ci-$ts-$rand';
  }

  /// Generates a unique message ID using a monotonic counter + timestamp.
  String _nextMsgId(String prefix) {
    _msgIdCounter += 1;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_msgIdCounter';
  }

  /// Guards that the adapter is in the [connected] state before sending.
  ///
  /// Throws [StateError] if not connected.  This matches the behaviour of
  /// [FakeVhrpTransport.sendBytes] which also throws [StateError] when not
  /// connected — providing a consistent error surface to callers regardless of
  /// whether the guard or the transport fires first.
  ///
  /// Decision: throw rather than silently swallow, because the caller semantics
  /// of every send* method imply "send AND generate a response".  Swallowing
  /// would leave the caller assuming a response is in-flight when it is not.
  // ── Session.instructions.set also needs _sendMsg ──────────────────────────

  void _ensureConnected() {
    if (!_connectionState.isConnected) {
      throw StateError(
        'VhrpRealtimeAdapter: cannot send while not connected '
        '(phase: ${_connectionState.phase.name}).',
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('VhrpRealtimeAdapter has been disposed.');
    }
  }
}
