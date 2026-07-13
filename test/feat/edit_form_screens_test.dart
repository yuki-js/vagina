import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/feat/speed_dial/screens/config.dart';
import 'package:vagina/feat/text_agents/screens/agent_form_screen.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';
import 'package:vagina/models/voice_agent.dart';

void main() {
  setUp(() async {
    AppContainer.reset();
    await AppContainer.initialize(store: InMemoryStore());
    AppContainer.setOverridesForTesting(
      speedDials: _SpeedDials(),
      voiceAgents: _VoiceAgents(),
      textAgents: _TextAgents(),
      textAgentModels: _TextAgentModels(),
    );
  });

  tearDown(AppContainer.reset);

  testWidgets('Speed Dial shows the bar after editing and discard restores', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SpeedDialConfigScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Assistant');
    await tester.pumpAndSettle();
    expect(find.text('You have unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 0);
    expect(_textFieldText(tester, find.byType(TextFormField).first), isEmpty);
  });

  testWidgets('Speed Dial text fields keep focus while editing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SpeedDialConfigScreen()));
    await tester.pump();

    final field = find.byType(TextFormField).first;
    await tester.tap(field);
    await tester.pump();
    tester.testTextInput.enterText('A');
    await tester.pump();

    expect(_textFieldHasFocus(tester, field), isTrue);
  });

  testWidgets('Speed Dial save stays open and hides the bar', (tester) async {
    await tester.pumpWidget(_app(const SpeedDialConfigScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Assistant');
    await tester.scrollUntilVisible(
      find.text('System prompt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final promptField = find.ancestor(
      of: find.text('System prompt'),
      matching: find.byType(Card),
    );
    await tester.enterText(
      find.descendant(of: promptField, matching: find.byType(TextFormField)),
      'Help',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(SpeedDialConfigScreen), findsOneWidget);
    expect(_barOpacity(tester), 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Text Agent shows the bar after editing and discard restores', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AgentFormScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Agent');
    await tester.pumpAndSettle();
    expect(find.text('You have unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 0);
    expect(_textFieldText(tester, find.byType(TextFormField).first), isEmpty);
  });

  testWidgets('Text Agent text fields keep focus while editing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AgentFormScreen()));
    await tester.pump();

    final field = find.byType(TextFormField).first;
    await tester.tap(field);
    await tester.pump();
    tester.testTextInput.enterText('A');
    await tester.pump();

    expect(_textFieldHasFocus(tester, field), isTrue);
  });

  testWidgets('Text Agent save stays open and hides the bar', (tester) async {
    await tester.pumpWidget(_app(const AgentFormScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Agent');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AgentFormScreen), findsOneWidget);
    expect(_barOpacity(tester), 0);
    expect(find.byType(SnackBar), findsNothing);
  });
}

double _barOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(
      of: find.text('You have unsaved changes'),
      matching: find.byType(AnimatedOpacity),
    ),
  );
  return opacity.opacity;
}

bool _textFieldHasFocus(WidgetTester tester, Finder field) {
  final editableText = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  return editableText.focusNode.hasFocus;
}

String _textFieldText(WidgetTester tester, Finder field) {
  final editableText = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  return editableText.controller.text;
}

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

class _VoiceAgents implements VoiceAgentRepository {
  @override
  Future<List<VoiceAgent>> listVoiceAgents() async => const [
    VoiceAgent(
      id: 'voice',
      displayName: 'Voice',
      isDefault: true,
      isAvailable: true,
    ),
  ];
}

class _TextAgentModels implements TextAgentModelRepository {
  @override
  Future<List<TextAgentModelPreset>> listTextAgentModels() async => const [
    TextAgentModelPreset(
      id: 'model',
      displayName: 'Model',
      isDefault: true,
      isAvailable: true,
    ),
  ];
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
  }) async => SpeedDial(id: 'new', name: name, systemPrompt: systemPrompt);
  @override
  Future<bool> update(SpeedDial speedDial) async => true;
  @override
  Future<bool> delete(String id) async => true;
  @override
  Future<List<SpeedDial>> getAll() async => const [];
  @override
  Future<SpeedDial?> getById(String id) async => null;
}

class _TextAgents implements TextAgentRepository {
  @override
  Future<TextAgentDefinition> create({
    required String name,
    required String prompt,
    String? description,
    String textModelId = TextAgentDefinition.defaultTextModelId,
    Map<String, bool> enabledTools = const {},
  }) async => TextAgentDefinition(id: 'new', name: name, prompt: prompt);
  @override
  Future<bool> update(TextAgentDefinition textAgent) async => true;
  @override
  Future<bool> delete(String id) async => true;
  @override
  Future<List<TextAgentDefinition>> getAll() async => const [];
  @override
  Future<TextAgentDefinition?> getById(String id) async => null;
}
