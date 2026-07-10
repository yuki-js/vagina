import 'package:flutter/foundation.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/voice_agent_repository.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/voice_agent.dart';

@immutable
class SpeedDialFormDraft {
  final String name;
  final String description;
  final String systemPrompt;
  final String voice;
  final String voiceAgentId;
  final String emoji;
  final Map<String, bool> enabledTools;
  final SpeedDialReasoningEffort reasoningEffort;
  final bool toolChoiceRequired;

  const SpeedDialFormDraft({
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.voice,
    required this.voiceAgentId,
    required this.emoji,
    required this.enabledTools,
    required this.reasoningEffort,
    required this.toolChoiceRequired,
  });

  factory SpeedDialFormDraft.initial() => const SpeedDialFormDraft(
    name: '',
    description: '',
    systemPrompt: '',
    voice: 'alloy',
    voiceAgentId: SpeedDial.defaultVoiceAgentId,
    emoji: '⭐',
    enabledTools: {},
    reasoningEffort: SpeedDialReasoningEffort.off,
    toolChoiceRequired: false,
  );

  factory SpeedDialFormDraft.fromSpeedDial(SpeedDial speedDial) =>
      SpeedDialFormDraft(
        name: speedDial.name,
        description: speedDial.description ?? '',
        systemPrompt: speedDial.systemPrompt,
        voice: speedDial.voice,
        voiceAgentId: speedDial.voiceAgentId,
        emoji: speedDial.iconEmoji ?? '⭐',
        enabledTools: Map.unmodifiable(speedDial.enabledTools),
        reasoningEffort: speedDial.reasoningEffort,
        toolChoiceRequired: speedDial.toolChoiceRequired,
      );

  SpeedDialFormDraft copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    String? voice,
    String? voiceAgentId,
    String? emoji,
    Map<String, bool>? enabledTools,
    SpeedDialReasoningEffort? reasoningEffort,
    bool? toolChoiceRequired,
  }) => SpeedDialFormDraft(
    name: name ?? this.name,
    description: description ?? this.description,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    voice: voice ?? this.voice,
    voiceAgentId: voiceAgentId ?? this.voiceAgentId,
    emoji: emoji ?? this.emoji,
    enabledTools: Map.unmodifiable(enabledTools ?? this.enabledTools),
    reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    toolChoiceRequired: toolChoiceRequired ?? this.toolChoiceRequired,
  );

  @override
  bool operator ==(Object other) =>
      other is SpeedDialFormDraft &&
      name == other.name &&
      description == other.description &&
      systemPrompt == other.systemPrompt &&
      voice == other.voice &&
      voiceAgentId == other.voiceAgentId &&
      emoji == other.emoji &&
      reasoningEffort == other.reasoningEffort &&
      toolChoiceRequired == other.toolChoiceRequired &&
      mapEquals(enabledTools, other.enabledTools);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    systemPrompt,
    voice,
    voiceAgentId,
    emoji,
    reasoningEffort,
    toolChoiceRequired,
    Object.hashAllUnordered(enabledTools.entries),
  );
}

enum SpeedDialFormSection {
  basicInfo,
  voice,
  voiceAgent,
  systemPrompt,
  tools,
  reasoning,
}

@immutable
class SpeedDialFormErrors {
  final String? name;
  final String? systemPrompt;
  final String? voiceAgent;

  const SpeedDialFormErrors({this.name, this.systemPrompt, this.voiceAgent});

  static const empty = SpeedDialFormErrors();

  bool get isEmpty =>
      name == null && systemPrompt == null && voiceAgent == null;

  SpeedDialFormSection? get firstInvalidSection {
    if (name != null) return SpeedDialFormSection.basicInfo;
    if (voiceAgent != null) return SpeedDialFormSection.voiceAgent;
    if (systemPrompt != null) return SpeedDialFormSection.systemPrompt;
    return null;
  }
}

@immutable
class SpeedDialFormValidationMessages {
  final String nameRequired;
  final String systemPromptRequired;
  final String voiceAgentLoading;
  final String voiceAgentLoadFailed;
  final String voiceAgentInvalid;

  const SpeedDialFormValidationMessages({
    required this.nameRequired,
    required this.systemPromptRequired,
    required this.voiceAgentLoading,
    required this.voiceAgentLoadFailed,
    required this.voiceAgentInvalid,
  });
}

enum SpeedDialCatalogStatus { loading, ready, failed }

class SpeedDialFormController extends ChangeNotifier {
  final SpeedDialRepository _speedDialRepository;
  final VoiceAgentRepository _voiceAgentRepository;
  SpeedDial? _persisted;

  late SpeedDialFormDraft _baseline;
  late SpeedDialFormDraft _draft;
  SpeedDialFormErrors _errors = SpeedDialFormErrors.empty;
  SpeedDialCatalogStatus _catalogStatus = SpeedDialCatalogStatus.loading;
  List<VoiceAgent> _voiceAgents = const [];
  Object? _saveError;
  bool _isSaving = false;

  SpeedDialFormController({
    required SpeedDialRepository speedDialRepository,
    required VoiceAgentRepository voiceAgentRepository,
    SpeedDial? original,
  }) : _speedDialRepository = speedDialRepository,
       _voiceAgentRepository = voiceAgentRepository,
       _persisted = original {
    _baseline = original == null
        ? SpeedDialFormDraft.initial()
        : SpeedDialFormDraft.fromSpeedDial(original);
    _draft = _baseline;
  }

  SpeedDial? get original => _persisted;
  SpeedDialFormDraft get draft => _draft;
  SpeedDialFormErrors get errors => _errors;
  SpeedDialCatalogStatus get catalogStatus => _catalogStatus;
  List<VoiceAgent> get voiceAgents => _voiceAgents;
  Object? get saveError => _saveError;
  bool get isSaving => _isSaving;
  bool get isNew => _persisted == null;
  bool get isDirty => _draft != _baseline;
  bool get canLeave => !isDirty && !_isSaving;

  Future<void> loadVoiceAgents() async {
    if (_isSaving) return;
    _catalogStatus = SpeedDialCatalogStatus.loading;
    notifyListeners();
    try {
      final agents = await _voiceAgentRepository.listVoiceAgents();
      _voiceAgents = List.unmodifiable(agents);
      _catalogStatus = SpeedDialCatalogStatus.ready;
      final selectedAvailable = agents.any(
        (agent) => agent.id == _draft.voiceAgentId && agent.isAvailable,
      );
      if (!selectedAvailable) {
        final replacement = _defaultVoiceAgent(agents);
        if (replacement != null) {
          final wasClean = !isDirty;
          _draft = _draft.copyWith(voiceAgentId: replacement.id);
          if (wasClean) _baseline = _draft;
        }
      }
    } catch (error) {
      _voiceAgents = const [];
      _catalogStatus = SpeedDialCatalogStatus.failed;
    }
    notifyListeners();
  }

  VoiceAgent? _defaultVoiceAgent(List<VoiceAgent> agents) {
    for (final agent in agents) {
      if (agent.isAvailable && agent.isDefault) return agent;
    }
    for (final agent in agents) {
      if (agent.isAvailable) return agent;
    }
    return null;
  }

  void updateName(String value) => _update(_draft.copyWith(name: value));
  void updateDescription(String value) =>
      _update(_draft.copyWith(description: value));
  void updateSystemPrompt(String value) =>
      _update(_draft.copyWith(systemPrompt: value));
  void updateVoice(String value) => _update(_draft.copyWith(voice: value));
  void updateVoiceAgentId(String value) =>
      _update(_draft.copyWith(voiceAgentId: value));
  void updateEmoji(String value) => _update(_draft.copyWith(emoji: value));
  void updateEnabledTools(Map<String, bool> value) =>
      _update(_draft.copyWith(enabledTools: value));
  void updateReasoningEffort(SpeedDialReasoningEffort value) =>
      _update(_draft.copyWith(reasoningEffort: value));
  void updateToolChoiceRequired(bool value) =>
      _update(_draft.copyWith(toolChoiceRequired: value));

  void _update(SpeedDialFormDraft next) {
    if (_isSaving || next == _draft) return;
    _draft = next;
    _saveError = null;
    notifyListeners();
  }

  void discard() {
    if (_isSaving || !isDirty) return;
    _draft = _baseline;
    _errors = SpeedDialFormErrors.empty;
    _saveError = null;
    notifyListeners();
  }

  SpeedDialFormErrors validate(SpeedDialFormValidationMessages messages) {
    String? voiceAgentError;
    if (_catalogStatus == SpeedDialCatalogStatus.loading) {
      voiceAgentError = messages.voiceAgentLoading;
    } else if (_catalogStatus == SpeedDialCatalogStatus.failed) {
      voiceAgentError = messages.voiceAgentLoadFailed;
    } else if (!_voiceAgents.any(
      (agent) => agent.id == _draft.voiceAgentId && agent.isAvailable,
    )) {
      voiceAgentError = messages.voiceAgentInvalid;
    }
    _errors = SpeedDialFormErrors(
      name: _draft.name.trim().isEmpty ? messages.nameRequired : null,
      systemPrompt: _draft.systemPrompt.trim().isEmpty
          ? messages.systemPromptRequired
          : null,
      voiceAgent: voiceAgentError,
    );
    notifyListeners();
    return _errors;
  }

  Future<bool> save(SpeedDialFormValidationMessages messages) async {
    if (_isSaving || !isDirty || !validate(messages).isEmpty) return false;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final description = _draft.description.trim();
      final persisted = _persisted;
      if (persisted == null) {
        _persisted = await _speedDialRepository.create(
          name: _draft.name,
          description: description.isEmpty ? null : description,
          systemPrompt: _draft.systemPrompt,
          voice: _draft.voice,
          voiceAgentId: _draft.voiceAgentId,
          iconEmoji: _draft.emoji,
          enabledTools: Map.of(_draft.enabledTools),
          reasoningEffort: _draft.reasoningEffort,
          toolChoiceRequired: _draft.toolChoiceRequired,
        );
      } else {
        await _speedDialRepository.update(
          SpeedDial(
            id: persisted.id,
            name: _draft.name,
            description: description.isEmpty ? null : description,
            systemPrompt: _draft.systemPrompt,
            voice: _draft.voice,
            voiceAgentId: _draft.voiceAgentId,
            iconEmoji: _draft.emoji,
            enabledTools: Map.of(_draft.enabledTools),
            reasoningEffort: _draft.reasoningEffort,
            toolChoiceRequired: _draft.toolChoiceRequired,
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
