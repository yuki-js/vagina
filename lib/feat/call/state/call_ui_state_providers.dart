import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'call_ui_state_providers.g.dart';

@Riverpod(dependencies: [])
class IsMuted extends _$IsMuted {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}

@Riverpod(dependencies: [])
class SpeakerMuted extends _$SpeakerMuted {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}

@Riverpod(dependencies: [])
class NoiseReduction extends _$NoiseReduction {
  static const validValues = ['near', 'far'];

  @override
  String build() => 'near';

  void toggle() {
    state = state == 'near' ? 'far' : 'near';
  }

  void set(String value) {
    if (validValues.contains(value)) {
      state = value;
    }
  }
}
