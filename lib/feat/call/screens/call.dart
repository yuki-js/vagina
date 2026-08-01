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
import 'package:vagina/feat/call/services/push_to_talk_key_source.dart';
import 'package:vagina/feat/call/widgets/call_screen_shell.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/models/speed_dial.dart';

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
  late final PushToTalkKeySource _pushToTalkKeySource;
  StreamSubscription<CallState>? _callStateSubscription;
  StreamSubscription<bool>? _pushToTalkHeldSubscription;
  bool _preferredPushToTalkEnabled = false;
  PushToTalkKeyBinding? _preferredPushToTalkKeyBinding;

  @override
  void initState() {
    super.initState();
    _callService = CallService(filesystemRepository: AppContainer.filesystem);
    _pushToTalkKeySource = PushToTalkKeySource();

    // Both keyboard routes arrive here already merged, so this is the only
    // place either of them reaches CallService.
    _pushToTalkHeldSubscription = _pushToTalkKeySource.heldUpdates.listen((
      held,
    ) {
      if (held) {
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
      unawaited(_syncPushToTalkKeySource().catchError((_) {}));
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

      await _syncPushToTalkKeySource();
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
    await _syncPushToTalkKeySource();
  }

  /// キーソースのbindingと有効状態を現在のdesired stateに合わせる。
  ///
  /// 直列化はキーソース側が持っているため、ここでは順に渡すだけでよい。
  Future<void> _syncPushToTalkKeySource() async {
    final enabled =
        _callService.state == CallState.active && _preferredPushToTalkEnabled;

    await _pushToTalkKeySource.setBinding(_preferredPushToTalkKeyBinding);
    await _pushToTalkKeySource.setEnabled(enabled);

    // 無効化はPTTを中断させる。押しっぱなしのまま無効になった場合、キーソースは
    // heldをfalseに落とすためendPushToTalk()が走るが、本来ここは音声を送らず
    // 破棄する場面。cancelPushToTalk()が世代カウンタを進めることで、
    // endPushToTalk()の200msデバウンス中の送信が取り消される。
    if (!enabled) {
      await _callService.cancelPushToTalk();
    }
  }

  @override
  void dispose() {
    _pushToTalkHeldSubscription?.cancel();
    _pushToTalkHeldSubscription = null;
    unawaited(_pushToTalkKeySource.dispose());
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
              pushToTalkKeyHeld: _pushToTalkKeySource.heldUpdates,
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
