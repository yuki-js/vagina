import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_providers.g.dart';

/// Holds the current app locale override language code.
///
/// A `null` value means the app should follow the system locale.
@riverpod
class AppLocaleCode extends _$AppLocaleCode {
  @override
  String? build() => null;

  void setLocaleCode(String? localeCode) => state = localeCode;
}
