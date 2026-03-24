import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/panes/call.dart';
import 'package:vagina/feat/callv2/panes/chat.dart';
import 'package:vagina/feat/callv2/panes/notepad.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/widgets/call_screen_shell.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/tools/tools.dart';
import 'package:vagina/utils/url_utils.dart';

/// Temporary layout scaffold for the call rework.
class CallScreen extends StatefulWidget {
  final SpeedDial speedDial;

  const CallScreen({
    super.key,
    required this.speedDial,
  });

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
      filesystemRepository: RepositoryFactory.filesystem,
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
          title: const Text('接続できません'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
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
  final configRepository = RepositoryFactory.config;
  final realtimeUrl = await configRepository.getRealtimeUrl();
  final apiKey = await configRepository.getApiKey();
  final parsedRealtimeUrl =
      realtimeUrl == null ? null : UrlUtils.parseAzureRealtimeUrl(realtimeUrl);

  return VoiceAgentInfo(
    id: speedDial.id,
    name: speedDial.name,
    description: 'TODO: Add description to SpeedDial and show it here',
    iconEmoji: speedDial.iconEmoji,
    voice: speedDial.voice,
    prompt: speedDial.systemPrompt,
    enabledTools: toolbox.tools
        .map((tool) => tool.definition.toolKey)
        .where((toolKey) => speedDial.enabledTools[toolKey] ?? true)
        .toList(growable: false),
    apiConfig: SelfhostedVoiceAgentApiConfig(
      providerType: VoiceAgentProviderType.azureOpenAi,
      baseUrl: parsedRealtimeUrl?['endpoint'] ?? '',
      apiKey: apiKey ?? '',
      model: parsedRealtimeUrl?['deployment'] ?? 'gpt-4o-realtime-preview',
      params: <String, Object?>{
        if (parsedRealtimeUrl?['deployment'] case final deployment?)
          'deployment': deployment,
        if (parsedRealtimeUrl?['apiVersion'] case final apiVersion?)
          'apiVersion': apiVersion,
      },
    ),
  );
}

Future<List<TextAgentInfo>> _buildTextAgents() async {
  final configRepository = RepositoryFactory.config;
  final agents = await configRepository.getAllTextAgents();

  return agents.map(_mapTextAgentInfo).toList(growable: false);
}

TextAgentInfo _mapTextAgentInfo(TextAgent agent) {
  return TextAgentInfo(
    id: agent.id,
    name: agent.name,
    description: agent.description ?? '',
    prompt: '',
    enabledTools: toolbox.tools
        .map((tool) => tool.definition.toolKey)
        .where((toolKey) => agent.enabledTools[toolKey] ?? true)
        .toList(growable: false),
    apiConfig: _mapTextAgentApiConfig(agent),
  );
}

TextAgentApiConfig _mapTextAgentApiConfig(TextAgent agent) {
  final config = agent.config;
  final provider = config.provider;

  if (provider.value != 'azure') {
    throw UnsupportedError(
      'Only Azure text agents are supported in CallV2 currently: ${agent.id}',
    );
  }

  return SelfhostedTextAgentApiConfig(
    provider: provider.value,
    baseUrl: config.apiIdentifier,
    apiKey: config.apiKey,
    model: config.getModelIdentifier(),
  );
}
