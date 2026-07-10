import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/feat/text_agents/widgets/text_agent_model_section.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

void main() {
  testWidgets('renders loading and available model states', (tester) async {
    final models = _Models();
    final controller = TextAgentFormController(
      repository: _Agents(),
      modelRepository: models,
    );
    await tester.pumpWidget(_app(controller));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    models.models = const [
      TextAgentModelPreset(
        id: 'model',
        displayName: 'Model',
        isDefault: true,
        isAvailable: true,
      ),
    ];
    await controller.loadModels();
    await tester.pump();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.textContaining('Model'), findsWidgets);
  });
}

Widget _app(TextAgentFormController controller) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: TextAgentModelSection(controller: controller)),
);

class _Models implements TextAgentModelRepository {
  List<TextAgentModelPreset> models = const [];
  @override
  Future<List<TextAgentModelPreset>> listTextAgentModels() async => models;
}

class _Agents implements TextAgentRepository {
  @override
  Future<TextAgentDefinition> create({
    required String name,
    required String prompt,
    String? description,
    String textModelId = TextAgentDefinition.defaultTextModelId,
    Map<String, bool> enabledTools = const {},
  }) => throw UnimplementedError();
  @override
  Future<bool> update(TextAgentDefinition textAgent) =>
      throw UnimplementedError();
  @override
  Future<bool> delete(String id) => throw UnimplementedError();
  @override
  Future<List<TextAgentDefinition>> getAll() => throw UnimplementedError();
  @override
  Future<TextAgentDefinition?> getById(String id) => throw UnimplementedError();
}
