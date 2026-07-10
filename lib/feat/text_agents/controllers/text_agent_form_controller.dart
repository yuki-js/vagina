import 'package:flutter/foundation.dart';
import 'package:vagina/interfaces/text_agent_model_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

@immutable
class TextAgentFormDraft {
  final String name;
  final String description;
  final String prompt;
  final String? textModelId;
  final Map<String, bool> enabledTools;

  const TextAgentFormDraft({
    required this.name,
    required this.description,
    required this.prompt,
    required this.textModelId,
    required this.enabledTools,
  });

  factory TextAgentFormDraft.initial() => const TextAgentFormDraft(
    name: '',
    description: '',
    prompt: '',
    textModelId: null,
    enabledTools: {},
  );

  factory TextAgentFormDraft.fromAgent(TextAgentDefinition agent) =>
      TextAgentFormDraft(
        name: agent.name,
        description: agent.description ?? '',
        prompt: agent.prompt,
        textModelId: agent.textModelId,
        enabledTools: Map.unmodifiable(agent.enabledTools),
      );

  TextAgentFormDraft copyWith({
    String? name,
    String? description,
    String? prompt,
    String? textModelId,
    Map<String, bool>? enabledTools,
  }) => TextAgentFormDraft(
    name: name ?? this.name,
    description: description ?? this.description,
    prompt: prompt ?? this.prompt,
    textModelId: textModelId ?? this.textModelId,
    enabledTools: Map.unmodifiable(enabledTools ?? this.enabledTools),
  );

  @override
  bool operator ==(Object other) =>
      other is TextAgentFormDraft &&
      name == other.name &&
      description == other.description &&
      prompt == other.prompt &&
      textModelId == other.textModelId &&
      mapEquals(enabledTools, other.enabledTools);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    prompt,
    textModelId,
    Object.hashAllUnordered(enabledTools.entries),
  );
}

enum TextAgentFormSection { basicInfo, model, tools }

enum TextAgentCatalogStatus { loading, ready, failed }

@immutable
class TextAgentFormErrors {
  final String? name;
  final String? model;

  const TextAgentFormErrors({this.name, this.model});
  static const empty = TextAgentFormErrors();
  bool get isEmpty => name == null && model == null;
  TextAgentFormSection? get firstInvalidSection {
    if (name != null) return TextAgentFormSection.basicInfo;
    if (model != null) return TextAgentFormSection.model;
    return null;
  }
}

@immutable
class TextAgentFormValidationMessages {
  final String nameRequired;
  final String modelLoading;
  final String modelLoadFailed;
  final String modelInvalid;

  const TextAgentFormValidationMessages({
    required this.nameRequired,
    required this.modelLoading,
    required this.modelLoadFailed,
    required this.modelInvalid,
  });
}

class TextAgentFormController extends ChangeNotifier {
  final TextAgentRepository _repository;
  final TextAgentModelRepository _modelRepository;
  TextAgentDefinition? _persisted;

  late TextAgentFormDraft _baseline;
  late TextAgentFormDraft _draft;
  TextAgentFormErrors _errors = TextAgentFormErrors.empty;
  TextAgentCatalogStatus _catalogStatus = TextAgentCatalogStatus.loading;
  List<TextAgentModelPreset> _models = const [];
  Object? _catalogError;
  Object? _saveError;
  bool _isSaving = false;

  TextAgentFormController({
    required TextAgentRepository repository,
    required TextAgentModelRepository modelRepository,
    TextAgentDefinition? original,
  }) : _repository = repository,
       _modelRepository = modelRepository,
       _persisted = original {
    _baseline = original == null
        ? TextAgentFormDraft.initial()
        : TextAgentFormDraft.fromAgent(original);
    _draft = _baseline;
  }

  TextAgentDefinition? get original => _persisted;
  TextAgentFormDraft get draft => _draft;
  TextAgentFormErrors get errors => _errors;
  TextAgentCatalogStatus get catalogStatus => _catalogStatus;
  List<TextAgentModelPreset> get models => _models;
  Object? get catalogError => _catalogError;
  Object? get saveError => _saveError;
  bool get isSaving => _isSaving;
  bool get isNew => _persisted == null;
  bool get isDirty => _draft != _baseline;
  bool get canLeave => !isDirty && !_isSaving;

  Future<void> loadModels() async {
    if (_isSaving) return;
    _catalogStatus = TextAgentCatalogStatus.loading;
    _catalogError = null;
    notifyListeners();
    try {
      final models = await _modelRepository.listTextAgentModels();
      _models = List.unmodifiable(models);
      _catalogStatus = TextAgentCatalogStatus.ready;
      final selectedAvailable = models.any(
        (model) => model.id == _draft.textModelId && model.isAvailable,
      );
      if (!selectedAvailable) {
        final replacement = _defaultModel(models);
        if (replacement != null) {
          final wasClean = !isDirty;
          _draft = _draft.copyWith(textModelId: replacement.id);
          if (wasClean) _baseline = _draft;
        }
      }
    } catch (error) {
      _models = const [];
      _catalogStatus = TextAgentCatalogStatus.failed;
      _catalogError = error;
    }
    notifyListeners();
  }

  TextAgentModelPreset? _defaultModel(List<TextAgentModelPreset> models) {
    for (final model in models) {
      if (model.isDefault && model.isAvailable) return model;
    }
    for (final model in models) {
      if (model.isAvailable) return model;
    }
    return null;
  }

  void updateName(String value) => _update(_draft.copyWith(name: value));
  void updateDescription(String value) =>
      _update(_draft.copyWith(description: value));
  void updatePrompt(String value) => _update(_draft.copyWith(prompt: value));
  void updateTextModelId(String value) =>
      _update(_draft.copyWith(textModelId: value));
  void updateEnabledTools(Map<String, bool> value) =>
      _update(_draft.copyWith(enabledTools: value));

  void _update(TextAgentFormDraft next) {
    if (_isSaving || next == _draft) return;
    _draft = next;
    _saveError = null;
    notifyListeners();
  }

  void discard() {
    if (_isSaving || !isDirty) return;
    _draft = _baseline;
    _errors = TextAgentFormErrors.empty;
    _saveError = null;
    notifyListeners();
  }

  TextAgentFormErrors validate(TextAgentFormValidationMessages messages) {
    String? modelError;
    if (_catalogStatus == TextAgentCatalogStatus.loading) {
      modelError = messages.modelLoading;
    } else if (_catalogStatus == TextAgentCatalogStatus.failed) {
      modelError = messages.modelLoadFailed;
    } else if (!_models.any(
      (model) => model.id == _draft.textModelId && model.isAvailable,
    )) {
      modelError = messages.modelInvalid;
    }
    _errors = TextAgentFormErrors(
      name: _draft.name.trim().isEmpty ? messages.nameRequired : null,
      model: modelError,
    );
    notifyListeners();
    return _errors;
  }

  Future<bool> save(TextAgentFormValidationMessages messages) async {
    if (_isSaving || !isDirty || !validate(messages).isEmpty) return false;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final description = _draft.description.trim();
      final persisted = _persisted;
      if (persisted == null) {
        _persisted = await _repository.create(
          name: _draft.name.trim(),
          description: description.isEmpty ? null : description,
          prompt: _draft.prompt.trim(),
          textModelId: _draft.textModelId!,
          enabledTools: Map.of(_draft.enabledTools),
        );
      } else {
        await _repository.update(
          TextAgentDefinition(
            id: persisted.id,
            name: _draft.name.trim(),
            description: description.isEmpty ? null : description,
            prompt: _draft.prompt.trim(),
            textModelId: _draft.textModelId!,
            enabledTools: Map.of(_draft.enabledTools),
            createdAt: persisted.createdAt,
          ),
        );
      }
      _baseline = _draft;
      return true;
    } catch (error) {
      _saveError = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
