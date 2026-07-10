import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/voice_agent.dart';

const messages = SpeedDialFormValidationMessages(
  nameRequired: 'name required',
  systemPromptRequired: 'prompt required',
  voiceAgentLoading: 'loading',
  voiceAgentLoadFailed: 'load failed',
  voiceAgentInvalid: 'invalid agent',
);

void main() {
  late _SpeedDialRepository repository;
  late _VoiceAgentRepository voiceAgents;
  late SpeedDialFormController controller;

  setUp(() {
    repository = _SpeedDialRepository();
    voiceAgents = _VoiceAgentRepository();
    controller = SpeedDialFormController(
      speedDialRepository: repository,
      voiceAgentRepository: voiceAgents,
    );
  });

  test('tracks dirty state and discard restores the baseline', () {
    expect(controller.isDirty, isFalse);
    controller.updateName('Assistant');
    expect(controller.isDirty, isTrue);
    controller.updateName('');
    expect(controller.isDirty, isFalse);
    controller.updateEmoji('🤖');
    controller.discard();
    expect(controller.draft.emoji, '⭐');
    expect(controller.isDirty, isFalse);
  });

  test('loads catalog and replaces unavailable clean selection', () async {
    voiceAgents.result = const [
      VoiceAgent(
        id: 'available',
        displayName: 'Available',
        isDefault: true,
        isAvailable: true,
      ),
    ];
    await controller.loadVoiceAgents();
    expect(controller.catalogStatus, SpeedDialCatalogStatus.ready);
    expect(controller.draft.voiceAgentId, 'available');
    expect(controller.isDirty, isFalse);
  });

  test('reports typed validation errors in section order', () async {
    final loadingErrors = controller.validate(messages);
    expect(loadingErrors.name, 'name required');
    expect(loadingErrors.voiceAgent, 'loading');
    expect(loadingErrors.firstInvalidSection, SpeedDialFormSection.basicInfo);

    voiceAgents.error = StateError('offline');
    await controller.loadVoiceAgents();
    controller.updateName('Assistant');
    final errors = controller.validate(messages);
    expect(errors.voiceAgent, 'load failed');
    expect(errors.firstInvalidSection, SpeedDialFormSection.voiceAgent);
  });

  test('creates with the complete draft and clears dirty state', () async {
    voiceAgents.result = const [
      VoiceAgent(
        id: 'voice',
        displayName: 'Voice',
        isDefault: true,
        isAvailable: true,
      ),
    ];
    await controller.loadVoiceAgents();
    controller.updateName('Assistant');
    controller.updateSystemPrompt('Help');
    controller.updateDescription(' Description ');
    controller.updateEmoji('🤖');
    controller.updateEnabledTools({'calculate': false});

    expect(await controller.save(messages), isTrue);
    expect(repository.createdName, 'Assistant');
    expect(repository.createdDescription, 'Description');
    expect(repository.createdVoiceAgentId, 'voice');
    expect(repository.createdEnabledTools, {'calculate': false});
    expect(controller.isDirty, isFalse);
  });

  test('retains dirty draft after save failure and allows retry', () async {
    voiceAgents.result = const [
      VoiceAgent(
        id: 'voice',
        displayName: 'Voice',
        isDefault: true,
        isAvailable: true,
      ),
    ];
    await controller.loadVoiceAgents();
    controller.updateName('Assistant');
    controller.updateSystemPrompt('Help');
    repository.saveError = StateError('failed');

    expect(await controller.save(messages), isFalse);
    expect(controller.saveError, isA<StateError>());
    expect(controller.isDirty, isTrue);

    repository.saveError = null;
    expect(await controller.save(messages), isTrue);
    expect(controller.saveError, isNull);
  });
}

class _SpeedDialRepository implements SpeedDialRepository {
  Object? saveError;
  String? createdName;
  String? createdDescription;
  String? createdVoiceAgentId;
  Map<String, bool>? createdEnabledTools;

  @override
  Future<SpeedDial> create({
    required String name,
    required String systemPrompt,
    String? description,
    String? iconEmoji,
    String voice = 'alloy',
    String voiceAgentId = SpeedDial.defaultVoiceAgentId,
    Map<String, bool> enabledTools = const {},
    SpeedDialReasoningEffort reasoningEffort = SpeedDialReasoningEffort.off,
    bool toolChoiceRequired = false,
  }) async {
    if (saveError case final error?) throw error;
    createdName = name;
    createdDescription = description;
    createdVoiceAgentId = voiceAgentId;
    createdEnabledTools = enabledTools;
    return SpeedDial(id: 'new', name: name, systemPrompt: systemPrompt);
  }

  @override
  Future<bool> update(SpeedDial speedDial) async {
    if (saveError case final error?) throw error;
    return true;
  }

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<List<SpeedDial>> getAll() async => const [];

  @override
  Future<SpeedDial?> getById(String id) async => null;
}

class _VoiceAgentRepository implements VoiceAgentRepository {
  List<VoiceAgent> result = const [];
  Object? error;

  @override
  Future<List<VoiceAgent>> listVoiceAgents() async {
    if (error case final value?) throw value;
    return result;
  }
}
