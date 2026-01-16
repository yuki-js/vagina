import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui_preferences_provider.g.dart';

/// App-wide UI preference: use Material vs Cupertino widgets.
@Riverpod(keepAlive: true)
class UseCupertinoStyle extends _$UseCupertinoStyle {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}
