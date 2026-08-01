import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/text_agent_info_from_definition.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/panes/call.dart';
import 'package:vagina/feat/call/panes/chat.dart';
import 'package:vagina/feat/call/panes/notepad.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/widgets/call_screen_shell.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';
import 'package:vagina/services/platform/windows_virtual_key_codes.dart';

/// Layout scaffold for the call screen.
class CallScreen extends StatefulWidget {
  final SpeedDial speedDial;

  const CallScreen({super.key, required this.speedDial});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const double _wideLayoutBreakpoint = 900;

  final AdaptiveTriColumnController _layoutController =
      AdaptiveTriColumnController();
  late final CallService _callService;
  late final GlobalHotkeyService _globalHotkeyService;
  StreamSubscription<CallState>? _callStateSubscription;
  StreamSubscription<GlobalHotkeyTransition>? _globalHotkeySubscription;
  bool _preferredPushToTalkEnabled = false;
  PushToTalkKeyBinding? _preferredPushToTalkKeyBinding;

  /// dispose()の先頭でtrueになる。プラットフォーム往復中にdispose()が走った
  /// 場合に、解除より後からsetActive(true)が到達するのを防ぐためのガード。
  bool _disposed = false;

  /// グローバルホットキー操作の直列化チェーン。
  /// 古いsyncが新しいsyncのdesired stateを上書きしないよう、
  /// setBinding/setActiveの呼び出しは必ずこのチェーン上で順に実行する。
  Future<void> _globalHotkeySync = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _callService = CallService(filesystemRepository: AppContainer.filesystem);
    _globalHotkeyService = createGlobalHotkeyService();

    // Subscribe to global hotkey transitions
    _globalHotkeySubscription = _globalHotkeyService.transitions.listen((
      transition,
    ) {
      if (transition == GlobalHotkeyTransition.down) {
        unawaited(_callService.beginPushToTalk());
      } else {
        unawaited(_callService.endPushToTalk());
      }
    });

    // CallStateの変化を監視してpaneを再構築
    _callStateSubscription = _callService.states.listen((state) {
      if (!mounted) return;

      // disposed状態になったら画面を閉じる
      if (state == CallState.disposed) {
        Navigator.of(context).pop();
        return;
      }

      // 状態変化時にpaneを再構築
      setState(() {});
      unawaited(_scheduleGlobalHotkeySync().catchError((_) {}));
    });

    unawaited(_initializeCallService());
  }

  Future<void> _initializeCallService() async {
    try {
      final preferredPushToTalkEnabled = await AppContainer.preferences
          .getPreferredCallPushToTalkEnabled();
      final idleDisconnectTimeoutSeconds = await AppContainer.preferences
          .getPreferredCallIdleDisconnectTimeoutSeconds();
      final pushToTalkKeyBinding = await AppContainer.preferences
          .getPreferredCallPushToTalkKeyBinding();
      final voiceAgent = VoiceAgentInfo.fromSpeedDial(widget.speedDial);
      final textAgents = await _buildTextAgents();
      if (!mounted) return;

      setState(() {
        _preferredPushToTalkEnabled = preferredPushToTalkEnabled;
        _preferredPushToTalkKeyBinding = pushToTalkKeyBinding;
      });
      await _callService.setPushToTalkEnabled(preferredPushToTalkEnabled);
      _callService.setSilenceTimeout(
        Duration(seconds: idleDisconnectTimeoutSeconds),
      );
      _callService.setTextAgents(textAgents);
      _callService.setVoiceAgent(voiceAgent);
      await _callService.startCall();

      if (!mounted) {
        await _callService.endCall();
        return;
      }

      await _scheduleGlobalHotkeySync();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);

      // エラーダイアログを表示
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(l10n.callConnectionFailedTitle),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.callActionClose),
            ),
          ],
        ),
      );

      // ダイアログを閉じた後、通話画面も閉じる
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _savePushToTalkPreference(bool enabled) async {
    if (mounted && _preferredPushToTalkEnabled != enabled) {
      setState(() {
        _preferredPushToTalkEnabled = enabled;
      });
    } else {
      _preferredPushToTalkEnabled = enabled;
    }

    await AppContainer.preferences.setPreferredCallPushToTalkEnabled(enabled);
    await _scheduleGlobalHotkeySync();
  }

  /// [_syncGlobalHotkey]を直列化して実行する。
  ///
  /// 進行中のsync(およびdispose時のteardown)が完了してから次のsyncを走らせる
  /// ため、古い呼び出しが新しいdesired stateを上書きすることはない。
  /// 戻り値は今回スケジュールしたsync自身のFutureで、失敗はそのまま呼び出し元へ
  /// 伝播する（チェーン自体はcatchErrorで継続する）。
  Future<void> _scheduleGlobalHotkeySync() {
    final scheduled = _globalHotkeySync.then((_) => _syncGlobalHotkey());
    _globalHotkeySync = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> _syncGlobalHotkey() async {
    // dispose済みなら、以降のsetBinding/setActiveは一切実行しない。
    if (_disposed) return;

    final shouldEnable =
        _callService.state == CallState.active &&
        _preferredPushToTalkEnabled &&
        _preferredPushToTalkKeyBinding != null &&
        windowsGlobalHotkeyPayloadForBinding(_preferredPushToTalkKeyBinding!) !=
            null;

    if (shouldEnable) {
      await _globalHotkeyService.setBinding(_preferredPushToTalkKeyBinding);
      // プラットフォーム往復中にdispose()が走っている可能性があるため再確認。
      if (_disposed) return;
      await _globalHotkeyService.setActive(true);
    } else {
      await _globalHotkeyService.setActive(false);
    }
  }

  /// グローバルホットキーの解除とサービス解放。
  /// 直列化チェーン上で実行されるため、進行中のsyncのsetActive(true)が
  /// この解除より後に到達することはない。
  Future<void> _teardownGlobalHotkey() async {
    await _globalHotkeyService.setActive(false);
    await _globalHotkeyService.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _globalHotkeySubscription?.cancel();
    _globalHotkeySubscription = null;
    _globalHotkeySync = _globalHotkeySync
        .then((_) => _teardownGlobalHotkey())
        .catchError((_) {});
    unawaited(_globalHotkeySync);
    _callStateSubscription?.cancel();
    if (_callService.state != CallState.uninitialized &&
        _callService.state != CallState.disposed) {
      unawaited(_callService.endCall());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallScreenShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= _wideLayoutBreakpoint;

          return AdaptiveTriColumnLayout(
            controller: _layoutController,
            wideLayoutBreakpoint: _wideLayoutBreakpoint,
            onExitRequested: () {
              Navigator.of(context).pop();
            },
            left: ChatPane(
              onBackPressed: _layoutController.goToCenter,
              hideBackButton: isWideLayout,
              callService: _callService,
            ),
            center: CallPane(
              speedDial: widget.speedDial,
              callService: _callService,
              initialPushToTalkEnabled: _preferredPushToTalkEnabled,
              pushToTalkKeyBinding: _preferredPushToTalkKeyBinding,
              onPushToTalkPreferenceChanged: _savePushToTalkPreference,
              onChatPressed: _layoutController.goToLeft,
              onNotepadPressed: _layoutController.goToRight,
              hideNavigationButtons: isWideLayout,
            ),
            right: NotepadPane(
              onBackPressed: _layoutController.goToCenter,
              hideBackButton: isWideLayout,
              callService: _callService,
            ),
          );
        },
      ),
    );
  }
}

Future<List<TextAgentInfo>> _buildTextAgents() async {
  final textAgentRepository = AppContainer.textAgents;
  final definitions = await textAgentRepository.getAll();
  return definitions
      .map((definition) => definition.toCallTextAgentInfo())
      .toList(growable: false);
}
