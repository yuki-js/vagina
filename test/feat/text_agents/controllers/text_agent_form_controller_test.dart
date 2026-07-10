import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

const messages = TextAgentFormValidationMessages(
  nameRequired: 'name required',
  modelLoading: 'loading',
  modelLoadFailed: 'load failed',
  modelInvalid: 'invalid',
);

void main() {
  late _Repository repository;
  late _ModelRepository models;
  late TextAgentFormController controller;

  setUp(() {
    repository = _Repository();
    models = _ModelRepository();
    controller = TextAgentFormController(
      repository: repository,
      modelRepository: models,
    );
  });

  test('tracks and discards draft changes', () {
    controller.updateName('Agent');
    expect(controller.isDirty, isTrue);
    controller.updateName('');
    expect(controller.isDirty, isFalse);
    controller.updatePrompt('Prompt');
    controller.discard();
    expect(controller.draft.prompt, isEmpty);
  });

  test(
    'selects the available default model without making form dirty',
    () async {
      models.result = const [
        TextAgentModelPreset(
          id: 'model',
          displayName: 'Model',
          isDefault: true,
          isAvailable: true,
        ),
      ];
      await controller.loadModels();
      expect(controller.draft.textModelId, 'model');
      expect(controller.isDirty, isFalse);
    },
  );

  test('returns ordered typed validation errors', () {
    final errors = controller.validate(messages);
    expect(errors.name, 'name required');
    expect(errors.model, 'loading');
    expect(errors.firstInvalidSection, TextAgentFormSection.basicInfo);
  });

  test('creates complete definition and allows retry after failure', () async {
    models.result = const [
      TextAgentModelPreset(
        id: 'model',
        displayName: 'Model',
        isDefault: true,
        isAvailable: true,
      ),
    ];
    await controller.loadModels();
    controller.updateName(' Agent ');
    controller.updatePrompt(' Prompt ');
    controller.updateEnabledTools({'calculate': false});
    repository.error = StateError('failed');

    expect(await controller.save(messages), isFalse);
    expect(controller.isDirty, isTrue);
    repository.error = null;
    expect(await controller.save(messages), isTrue);
    expect(repository.name, 'Agent');
    expect(repository.prompt, 'Prompt');
    expect(repository.modelId, 'model');
    expect(repository.enabledTools, {'calculate': false});
  });
}

class _Repository implements TextAgentRepository {
  Object? error;
  String? name;
  String? prompt;
  String? modelId;
  Map<String, bool>? enabledTools;

  @override
  Future<TextAgentDefinition> create({
    required String name,
    required String prompt,
    String? description,
    String textModelId = TextAgentDefinition.defaultTextModelId,
    Map<String, bool> enabledTools = const {},
  }) async {
    if (error case final value?) throw value;
    this.name = name;
    this.prompt = prompt;
    modelId = textModelId;
    this.enabledTools = enabledTools;
    return TextAgentDefinition(id: 'new', name: name, prompt: prompt);
  }

  @override
  Future<bool> update(TextAgentDefinition textAgent) async => true;

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<List<TextAgentDefinition>> getAll() async => const [];

  @override
  Future<TextAgentDefinition?> getById(String id) async => null;
}

class _ModelRepository implements TextAgentModelRepository {
  List<TextAgentModelPreset> result = const [];

  @override
  Future<List<TextAgentModelPreset>> listTextAgentModels() async => result;
}
