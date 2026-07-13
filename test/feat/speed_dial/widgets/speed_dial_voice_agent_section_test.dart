import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_voice_agent_section.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/voice_agent.dart';

void main() {
  testWidgets('renders loading, failure with retry, and ready states', (
    tester,
  ) async {
    final voiceAgents = _VoiceAgents();
    final controller = SpeedDialFormController(
      speedDialRepository: _SpeedDials(),
      voiceAgentRepository: voiceAgents,
    );

    await tester.pumpWidget(_app(controller));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    voiceAgents.error = StateError('offline');
    await controller.loadVoiceAgents();
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    voiceAgents
      ..error = null
      ..agents = const [
        VoiceAgent(
          id: 'voice',
          displayName: 'Voice',
          isDefault: true,
          isAvailable: true,
        ),
      ];
    await controller.loadVoiceAgents();
    await tester.pump();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}

Widget _app(SpeedDialFormController controller) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SpeedDialVoiceAgentSection(controller: controller)),
);

class _VoiceAgents implements VoiceAgentRepository {
  List<VoiceAgent> agents = const [];
  Object? error;
  @override
  Future<List<VoiceAgent>> listVoiceAgents() async {
    if (error case final value?) throw value;
    return agents;
  }
}

class _SpeedDials implements SpeedDialRepository {
  @override
  Future<SpeedDial> create({
    required String name,
    required String systemPrompt,
    String? description,
    String? iconEmoji,
    String voice = 'alloy',
    String voiceAgentId = SpeedDial.defaultVoiceAgentId,
    Map<String, bool> enabledTools = const {},
    bool toolChoiceRequired = false,
  }) => throw UnimplementedError();
  @override
  Future<bool> update(SpeedDial speedDial) => throw UnimplementedError();
  @override
  Future<bool> delete(String id) => throw UnimplementedError();
  @override
  Future<List<SpeedDial>> getAll() => throw UnimplementedError();
  @override
  Future<SpeedDial?> getById(String id) => throw UnimplementedError();
}
