import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/panes/call.dart';
import 'package:vagina/feat/call/panes/chat.dart';
import 'package:vagina/feat/call/panes/notepad.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/widgets/call_screen_shell.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/tools/tools.dart';

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
  StreamSubscription<CallState>? _callStateSubscription;

  @override
  void initState() {
    super.initState();
    _callService = CallService(
      filesystemRepository: AppContainer.filesystem,
      sessionRepository: AppContainer.callSessions,
    );

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
    });

    unawaited(_initializeCallService());
  }

  Future<void> _initializeCallService() async {
    try {
      final voiceAgent = await _buildVoiceAgent(widget.speedDial);
      final textAgents = await _buildTextAgents();
      if (!mounted) return;

      _callService.setTextAgents(textAgents);
      _callService.setVoiceAgent(voiceAgent);
      await _callService.startCall();

      if (!mounted) {
        await _callService.endCall();
        return;
      }
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

  @override
  void dispose() {
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

Future<VoiceAgentInfo> _buildVoiceAgent(SpeedDial speedDial) async {
  final configRepository = AppContainer.config;
  final apiConfig = await configRepository.getVoiceAgentApiConfig();
  if (apiConfig == null) {
    throw StateError('Voice agent API config is not configured.');
  }
  return VoiceAgentInfo(
    id: speedDial.id,
    name: speedDial.name,
    description: speedDial.description ?? '',
    iconEmoji: speedDial.iconEmoji,
    voice: speedDial.voice,
    prompt: speedDial.systemPrompt,
    enabledTools: toolbox.tools
        .map((tool) => tool.definition.toolKey)
        .where((toolKey) => speedDial.enabledTools[toolKey] ?? true)
        .toList(growable: false),
    reasoningEffort: speedDial.reasoningEffort,
    toolChoiceRequired: speedDial.toolChoiceRequired,
    apiConfig: apiConfig,
  );
}

Future<List<TextAgentInfo>> _buildTextAgents() async {
  final configRepository = AppContainer.config;
  return configRepository.getAllTextAgents();
}
