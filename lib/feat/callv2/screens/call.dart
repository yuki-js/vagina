import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/panes/call.dart';
import 'package:vagina/feat/callv2/panes/chat.dart';
import 'package:vagina/feat/callv2/panes/notepad.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/widgets/call_screen_shell.dart';
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

  @override
  void initState() {
    super.initState();
    _callService = CallService(
      filesystemRepository: RepositoryFactory.filesystem,
    );
    unawaited(_initializeCallService());
  }

  Future<void> _initializeCallService() async {
    final voiceAgent = await _buildVoiceAgent(widget.speedDial);
    if (!mounted) {
      return;
    }

    _callService.setVoiceAgent(voiceAgent);
    await _callService.startCall();

    if (!mounted) {
      await _callService.endCall();
      return;
    }
  }

  @override
  void dispose() {
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
